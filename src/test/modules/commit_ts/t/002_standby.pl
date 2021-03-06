# Test simple scenario involving a standby

use strict;
use warnings;

use TestLib;
use Test::More tests => 2;
use PostgresNode;

my $bkplabel = 'backup';
my $master = get_new_node('master');
$master->init(allows_streaming => 1);

$master->append_conf('postgresql.conf', qq{
	track_commit_timestamp = on
	max_wal_senders = 5
	wal_level = hot_standby
	});
$master->start;
$master->backup($bkplabel);

my $standby = get_new_node('standby');
$standby->init_from_backup($master, $bkplabel, has_streaming => 1);
$standby->start;

for my $i (1 .. 10)
{
	$master->psql('postgres', "create table t$i()");
}
my $master_ts = $master->psql('postgres',
	qq{SELECT ts.* FROM pg_class, pg_xact_commit_timestamp(xmin) AS ts WHERE relname = 't10'});
my $master_lsn = $master->psql('postgres',
	'select pg_current_xlog_location()');
$standby->poll_query_until('postgres',
	qq{SELECT '$master_lsn'::pg_lsn <= pg_last_xlog_replay_location()})
	or die "slave never caught up";

my $standby_ts = $standby->psql('postgres',
	qq{select ts.* from pg_class, pg_xact_commit_timestamp(xmin) ts where relname = 't10'});
is($master_ts, $standby_ts, "standby gives same value as master");

$master->append_conf('postgresql.conf', 'track_commit_timestamp = off');
$master->restart;
$master->psql('postgres', 'checkpoint');
$master_lsn = $master->psql('postgres',
	'select pg_current_xlog_location()');
$standby->poll_query_until('postgres',
	qq{SELECT '$master_lsn'::pg_lsn <= pg_last_xlog_replay_location()})
	or die "slave never caught up";
$standby->psql('postgres', 'checkpoint');

# This one should raise an error now
$standby_ts = $standby->psql('postgres',
	'select ts.* from pg_class, pg_xact_commit_timestamp(xmin) ts where relname = \'t10\'');
is($standby_ts, '', "standby gives no value when master turned feature off");
