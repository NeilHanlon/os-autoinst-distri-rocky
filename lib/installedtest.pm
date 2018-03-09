package installedtest;
use base 'basetest';

# base class for tests that run on installed system

# should be used when with tests, where system is already installed, e. g all parts
# of upgrade tests, postinstall phases...

use testapi;
use utils;

sub root_console {
    # Switch to a default or specified TTY and log in as root, or
    # log in as regular user and sudo if no root password.
    my $self = shift;
    my %args = (
        tty => 1, # what TTY to login to
        @_);

    send_key "ctrl-alt-f$args{tty}";
    if (get_var("ROOT_PASSWORD") eq "false") {
        console_login(user=>get_var("USER_LOGIN", "test"), password=>get_var("USER_PASSWORD", "weakpassword"));
        type_string "sudo su";
        type_string get_var("USER_PASSWORD", "weakpassword");
        send_key "ret";
        assert_screen "root_console";
    }
    else {
        console_login;
    }
}

sub post_fail_hook {
    my $self = shift;

    if (check_screen 'emergency_rescue', 3) {
        my $password = get_var("ROOT_PASSWORD", "weakpassword");
        type_string "$password\n";
        # bring up network so we can upload logs
        assert_script_run "dhclient";
    }
    else {
        $self->root_console(tty=>6);
    }

    # We can't rely on tar being in minimal installs, but we also can't
    # rely on dnf always working (it fails in emergency mode, not sure
    # why), so try it, then check if we have tar
    script_run "dnf -y install tar", 180;
    assert_script_run "rpm -q tar";

    # Note: script_run returns the exit code, so the logic looks weird.
    # We're testing that the directory exists and contains something.
    unless (script_run 'test -n "$(ls -A /var/tmp/abrt)" && cd /var/tmp/abrt && tar czvf tmpabrt.tar.gz *') {
        upload_logs "/var/tmp/abrt/tmpabrt.tar.gz";
    }

    unless (script_run 'test -n "$(ls -A /var/spool/abrt)" && cd /var/spool/abrt && tar czvf spoolabrt.tar.gz *') {
        upload_logs "/var/spool/abrt/spoolabrt.tar.gz";
    }

    # Upload /var/log
    # lastlog can mess up tar sometimes and it's not much use
    unless (script_run "tar czvf /tmp/var_log.tar.gz --exclude='lastlog' /var/log") {
        upload_logs "/tmp/var_log.tar.gz";
    }

    # Sometimes useful for diagnosing FreeIPA issues
    upload_logs "/etc/nsswitch.conf", failok=>1;
}

1;

# vim: set sw=4 et:
