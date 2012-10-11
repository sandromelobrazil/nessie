#!/usr/bin/perl

$ENV{HTTPS_CA_FILE} = 'ca';

use Getopt::Long;
use Net::Nessus::XMLRPC;
use warnings;
use strict;
use Data::Dumper;

my $help;
my $list_policies;
my $list_scans;
my $list_reports;
my $delete_report;
my $pause_all;
my $resume_all;
my $stop_all;
my $scan;
my $policy;
my $name;
my $targets;
my $file;
my $download;
my $batch_size = 20;

my $server = 'https://127.0.0.1:8834/';
my $user = 'nessus';
my $password;

### evaluagte parameters
GetOptions ("list-policies"   => \$list_policies,
	    "list-scans"      => \$list_scans,
	    "list-reports"    => \$list_reports,
	    "delete-report=s" => \$delete_report,
	    "scan"            => \$scan,
	    "name=s"          => \$name,
	    "policy=s"        => \$policy,
	    "targets=s"       => \$targets,
	    "file=s"          => \$file,
	    "pause"           => \$pause_all,
	    "resume"          => \$resume_all,
	    "stop"            => \$stop_all,
	    "download=s"      => \$download,
	    "batch-size=i"    => \$batch_size,
            "help"            => \$help,
            "server=s"        => \$server,
            "user=s"          => \$user,
            "passwordr=s"     => \$password
);

### parse config


### login
my $n;
if(not $help) {
    $n = Net::Nessus::XMLRPC->new ($server, $user, $password);
    
    error_msg("cannot login to: " . $n->nurl()) unless ($n->logged_in());
    
    log_msg("connected to nessus xmlrpc service established and authenticated");
}


if($help) {
    print 
	"usage: $0 [ <options> ] <command> [ <command-options> ]\n\n",
        "  Options: \n",
	"  --server                 - XML-RPC URI of the nessus scan server\n",
	"  --user                   - nessus user\n",
	"  --password               - password\n",
	"\n",
	"  Commands:\n",
	"  --list-policies          - list available scan policies in nessus\n",
	"  --scan                   - start a new scan\n",
	"    --name <str>           - name of the scan\n",
	"    --policy <str|id>      - policy to use for scanning\n",
	"    --targets <addrs>      - targets to scan (e.g. '10.0.1.0/24, 10.0.2.0/24')\n",
	"    --file <str>           - specify a file with targets\n",
	"  --list-scans             - list running scans\n",
	"  --list-reports           - list reports\n",
	"  --download <id>          - download report\n",
	"  --delete-report <id|all> - download report\n",
#	"  --pause-scan         - pause a scan\n",
	"  --pause                  - pause all runnings scans\n",
	"  --resume                 - resume all scans\n",
	"  --stop                   - stop all scans\n",
	"  --batch-size             - split scans into batches (default size 20)\n",
	"\n\n";
    exit;
}
elsif($list_policies) {
    list_policies($n);
}
elsif($list_scans) {
    list_scans($n);
}
elsif($list_reports) {
    list_reports($n);
}
elsif($scan) {

    # check params
    check_param($name, "Please specify a scan name with --name.");
    check_param($policy, "Please specify a policy name with --policy.");

    # determin the policy
    my $policy_id;
    if($policy =~ m!^[\+\-]?\d+$!) {
	log_msg("treat policy parameter as policy id");
	$policy_id = $policy;
    }
    else {
	$policy_id = $n->policy_get_id($policy);
    }


    # start scan
    my $scan_id;
    log_msg("starting a new scan");

    if(defined($targets)) {
	$scan_id = $n->scan_new($policy_id, $name, $targets);
    }
    elsif(defined($file)) {
	$scan_id = $n->scan_new_file($policy_id, $name, $targets, $file);
    }
    else {
	error_msg("don't know what to scan");
    }

    if($scan_id eq '') {
	error_msg("scan failed.");
    }
    else {
	log_msg("started a new scan with id " . $scan_id);
    }
}
elsif($pause_all) {
    my $ret = $n->scan_pause_all();
    print "ret: $ret\n";
}

elsif($resume_all) {
    my $ret = $n->scan_resume_all();
    print "ret: $ret\n";
}
elsif($stop_all) {
    my $ret = $n->scan_stop_all();
    print "ret: $ret\n";
}
elsif(defined($download) and ($download ne '')) {

    my $err = 0;
    my $ret;

    if($download ne 'all') {
	download_report($n, $download, $download . ".nessus");
    }
    else {
	foreach my $report_id (list_reports($n)) {
	    download_report($n, $report_id, $report_id . ".nessus");
	}
    }
   
}
elsif(defined($delete_report) and ($delete_report ne '')) {
    my $err = 0;

    if($delete_report ne 'all') {
	if(not $n->report_delete($delete_report)) {
	    error_msg("Failed to delete report ${delete_report}.");
	    $err = 1;
	}
    }
    else {
	foreach my $report_id (list_reports($n)) {
	    log_msg("Remove report $report_id.");
	    if(not $n->report_delete($report_id)) {
		error_msg("Failed to delete report $report_id.");
		$err = 1;
	    }
	}
    }
    if(not $err) {
	log_msg("Report(s) deleted.");
    }
}
else {
    error_msg("Unknown command.");
}

#print "$scanid: ".$n->scan_status($scanid)."\n";        
#my $reportcont=$n->report_file_download($scanid);
#my $reportfile="report.xml";
#open (FILE,">$reportfile") or die "Cannot open file $reportfile: $!";
#print FILE $reportcont;
#close (FILE);

### helper functions

sub error_msg {
    my $msg = shift;
    print "\nerror: ", $msg, "\n\n";
    exit(1);
}

sub log_msg {
    my $msg = shift;
    print "+ ", $msg, "\n";
}

sub check_param {
    my ($param, $error_msg) = @_;
    if(not defined $param) {
	error_msg($error_msg);
    }
}

sub hashval_to_str {
    my ($h_ref, $h_key) = @_;
    return exists($h_ref->{$h_key}) && defined($h_ref->{$h_key}) ? $h_ref->{$h_key} : '';
}

sub shorten {
    my ($str, $max_len) = @_;

    if($max_len > 3 ) {
	$max_len -= 3;
    }

    if(length($str) > $max_len) {
	$str = substr($str, 0, $max_len) . '...';
    }
    return $str;
}

sub list_policies {
    my $n = shift;

    log_msg("get available policies:");
    my $p_list = $n->policy_list_hash();
    foreach my $pi (@$p_list) {
	printf("%3d  %-20s %-10s %-30s %-s\n",
	       hashval_to_str($pi, 'id'),
	       shorten(hashval_to_str($pi, 'owner'), 20),
	       hashval_to_str($pi, 'visibility'),
	       hashval_to_str($pi, 'name'),
	       hashval_to_str($pi, 'comment'));
    }
}


sub list_scans {
    my $n = shift;

    log_msg("get running scan(s)");
    my $s_list = $n->scan_list_uids();
    log_msg("found " . ($#$s_list + 1) . " scan(s)");

    if($#$s_list > -1) {
	printf("\n  %-52s  %-10s %s\n", "scan ID", "status", "scan name");
	print "  ", "-" x 80, "\n";
	foreach my $sid (@$s_list) {
	    my $name = $n->scan_get_name($sid);
	    my $stat = $n->scan_status($sid);
	    printf("  %s  %-10s %s\n", $sid, $stat, $name);
	}
	print "\n";
    }

}

sub list_reports {
    my $n = shift;

    my @report_ids;

    log_msg("get available reports:");
    my $r_list = $n->report_list_hash();
    log_msg("found " . ($#$r_list + 1) . " reports(s)");
  
    if($#$r_list > -1) {
	printf("\n  %-52s  %-10s %s\n", "scan ID", "status", "scan name");
	print "  ", "-" x 80, "\n";
	foreach my $ri (@$r_list) {
	    printf("  %s  %-10s %s\n", $ri->{name}, $ri->{status}, $ri->{readableName});
	    push @report_ids, $ri->{name};
	}
    }
    return @report_ids;
}

sub download_report {
    my ($n, $report_id, $report_file) = @_;
    
    my $ret = $n->report_file_download($report_id);
    
    if($ret) {
	open(FILE, "> $report_file") or error_msg("failed to write report file $report_file: $!");
	print FILE $ret;
	close FILE;
	log_msg("wrote " . length($ret) . " bytes to file " . $report_file);
    }
    else {
	error_msg("report download failed.");
    }
}

sub wait {
    
#    while (not $n->scan_finished($scanid)) {
#	print "$scanid: ".$n->scan_status($scanid)."\n";        
#	sleep 15;
#    }
}