use strict;
use Socket;
use POSIX;
eval {
	require Locale::gettext;
	Locale::gettext->require_version(1.04);
};
if ($@) {
	require Schulkonsole::Gettext;
}
use CGI qw(-utf8);
use CGI::Session qw(-ip_match);
use Crypt::CBC;
use Digest::MD5;
use Schulkonsole::Config;
use Schulkonsole::SophomorixConfig;
use Schulkonsole::Error::Error;
use Schulkonsole::DB;

use Template;
use Template::Constants qw ( :debug );


package Schulkonsole::Session;

=head1 NAME

Schulkonsole::Session - session management for schulkonsole

=head1 SYNOPSIS

 use Schulkonsole::Session;

 # create new session
 my $session = new Schulkonsole::Session('file.cgi');
 # create new session with additional textdomain 'name'
 my $session = new Schulkonsole::Session('file.cgi','name');
 
 my $q = $session->query(); # get CGI-object
 my $d = $session->d(); # get Locale::gettext-object
 my $d = $session->d($textdomain); # get Locale::gettext-object for $textdomain

 # get information from user data
 my $username = $session->userdata('uid');

 # set variable for HTML-output
 $session->set_var('username', $username);


 # set status information, mark as successful
 $session->set_status('ok', 0);

 # set status information, mark as failed
 $session->set_status('failed', 1);

 # put label for <input>-field 'username' in class="error"
 $session->mark_input_error('username');

 # produce output using template.tt.
 # unspecified <form>-action will be "file.cgi"
 $session->print_page('template.tt', 'file.cgi');

 # delete the underlying CGI::Session-object and
 # delete the user's session cookie
 $session->end_session;

=cut

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = 0.03;
@ISA = qw(Exporter);
@EXPORT_OK = qw(
);





=head1 DESCRIPTION

=head2 Public methods

=head3 C<new Schulkonsole::Session($page)>

Creates a new Schulkonsole::Session object.

=head4 Parameters

=over

=item C<$page>

If the user is not yet authenticated and the login page is displayed,
C<$page> will be the action of the login form.

=back

=head4 Return value

Returns the created object.

=head4 Description

C<new> does the basic initialization for a schulkonsole session. That is:
authentication, language settings (from the settings of the client),
and setting of user information in template variables

The following variables are set:

=over

=item C<username>

The user's login name

=item C<firstname>

The user's first name

=item C<surname>

The user's surname

=item C<groupname>

The user's group(s)

=item C<session_time>

Elapsed time since start of the current session

=item C<remote_room>

The room of the client's workstation as defined in /etc/linuxmuster/workstations

=item C<remote_workstation>

The name of the client's workstation as defined in /etc/linuxmuster/workstations

=item C<REMOTE_HOST>

Corresponds to the environment variable REMOTE_HOST

=item C<REMOTE_ADDR>

Corresponds to the environment variable REMOTE_ADDR

=item C<HTTP_HOST>

Corresponds to the environment variable HTTP_HOST

=item C<SERVER_ADDR>

Corresponds to the environment variable SERVER_ADDR

=item C<SERVER_NAME>

Corresponds to the environment variable SERVER_NAME

=back

=cut

sub new {
	my $class = shift;
	my $page = shift;
        my $plugin = shift;
        
	my $this = {
		template_vars => {},
		input_errors => {},
	};

	bless $this, $class;


	$this->init($page,$plugin);

	return $this;
}




=head3 C<end_session()>

=head4 Description

Deletes the underlying CGI::Session-object and the user's session cookie.
The information to delete the cookie will be submitted with the next
invocation of C<print_page()>.

=cut

sub end_session {
	my $this = shift;

	$this->{logout} = 1;

	my $sid = $this->{session}->id();

	$this->{session}->delete();

	my $session_lockfile = Schulkonsole::Config::lockfile('cgisession_' . $sid);
	unlink $session_lockfile;
}



=head3 C<print_header()>

=head4 Description

Saves the session data in a cookie for next invocation and sends header information.

=cut

sub print_header{
	my $this = shift;

		# if we have path-info the links within the page will not work
	# we should not be here
	my $path = $this->{query}->path_info();
	if ($path) {
		my $url = $this->{query}->url( -absolute => 1 );
		$url =~ s:/+$::; # delete multiple / remaining from path-info
		print $this->{query}->redirect( -uri => $url,
		                         -status => 303 );

		exit;
	}

	my $session_id = $this->{session}->id;

	my $old_session_id = $this->{query}->cookie(CGI::Session->name());
	my $no_cookies = 1 unless ($old_session_id or $this->{logout});

	if ($this->{logout}) {
		my @cookies = (
			$this->{query}->cookie(
				-name => $this->{session}->name,
				-value => 'expired',
				-expires => 'now',
				-path => $Schulkonsole::Config::_http_root,
				-secure => 1,
			),
			$this->{query}->cookie(
				-name => 'key',
				-value => 'expired',
				-expires => 'now',
				-path => $Schulkonsole::Config::_http_root,
				-secure => 1,
			),
		);
		print $this->{query}->header(-type => 'text/html', -charset => 'UTF-8',
								 -cookie => \@cookies, -expires => 'now' );
	} elsif (   $no_cookies
	         or $session_id ne $old_session_id) {
		my $cookie = $this->{query}->cookie(
			-name => $this->{session}->name,
			-value => $session_id,
			-path => $Schulkonsole::Config::_http_root,
			-secure => 1,
		);
		print $this->{query}->header( -type => 'text/html', -charset => 'UTF-8',
								-cookie => $cookie, -expires => 'now' );
	} elsif ($this->{key}) {
		my $cookie = $this->{query}->cookie(
			-name => 'key',
			-value => $this->{key},
			-path => $Schulkonsole::Config::_http_root,
			-secure => 1,
		);
		print $this->{query}->header( -type => 'text/html', -charset => 'UTF-8',
									-cookie => $cookie, -expires => 'now' );
	} else {
		print $this->{query}->header( -type => 'text/html', -charset => 'UTF-8',
									-expires => 'now' );
	}
	
	return $no_cookies;

}


=head3 C<set_var($var_name, $var_value)>

Sets a variable to be used in a template.

=head4 Parameters

=over

=item C<$var_name>

The name of the variable

=item C<$var_value>

The value of the variable

=back

=head4 Description

Sets the template variable C<$var_name> to the value C<$var_value>.

=cut

sub set_var {
	my $this = shift;

	my $var_name = shift;
	my $var_value = shift;

	$this->{template_vars}{$var_name} = CGI->escapeHTML($var_value);
}




=head3 C<param($param_name, $param_value)>

Set a session parameter

=head4 Parameters

=over

=item C<$param_name>

The name of the parameter

=item C<$param_value>

The value of the parameter

=back

=head4 Description

Sets the session parameter C<$param_name> to the value C<$param_value>.



=head3 C<param($param_name)>

Return a session parameter

=head4 Parameters

=over

=item C<$param_name>

The name of the parameter

=back

=head4 Return value

The value of the parameter

=head4 Description

Returns the value of the session parameter C<$param_name>.

=cut

sub param {
	my $this = shift;

	return $this->{session}->param(@_);
}



=head3 C<clear($param_name)>

Clear a session parameter

=head4 Parameters

=over

=item C<$param_name>

The name of the parameter

=back

=head4 Description

Clears the session parameter C<$param_name>.

=cut

sub clear {
	my $this = shift;
	my $param_name = shift;
	return if not defined $param_name;

	$this->{session}->clear([$param_name]);
}



=head3 C<temp_param($param_name, $param_value)>

Temporarily buffers a parameter

=head4 Parameters

=over

=item C<$param_name>

The name of the parameter

=item C<$param_value>

The value of the parameter

=back

=head4 Description

Sets the session parameter C<$param_name> to the value C<$param_value> plus
validity time.



=head3 C<temp_param($param_name)>

Return a buffered parameter

=head4 Parameters

=over

=item C<$param_name>

The name of the parameter

=back

=head4 Return value

The value of the parameter

=head4 Description

Returns the value of the parameter C<$param_name> or C<undef> if the value
is no longer valid.

=cut

sub temp_param {
	my $this = shift;
	my $param_name = shift;
	my $param_value = shift;

	if ($param_value) {
		if ($this->{query}->cookie(CGI::Session->name)) {
			$this->{session}->param($param_name,
				[ $param_value,
				  $^T + Schulkonsole::Config::expire_seconds(
				        	$Schulkonsole::Config::_tmp_valid_time)
				]);
		} else {
			$this->{session}->param($param_name, [ $param_value ]);
			$this->{session}->expire($param_name,
				$Schulkonsole::Config::_max_idle_time);
		}
	} else {
		my $param = $this->{session}->param($param_name);

		if ($param) {
			if (   not $$param[1]
			    or $^T < $$param[1]) {
				return $$param[0];
			} else {
				$this->{session}->clear($param_name);
				return undef;
			}
		} else {
			return undef;
		}
	}
}




=head3 C<set_status($status, $is_error)>

Set status description.

=head4 Parameters

=over

=item C<$status>

Description of the status

=item C<$is_error>

true, if the status is to be treated as error

=back

=head4 Description

Sets the status description of the last action. The status will be available
as the template variable C<status>. The CSS-class of the <div> with id
C<status> will be set to C<error> if C<$is_error> is true or to C<ok>
otherwise.

=cut

sub set_status {
	my $this = shift;

	my $status = shift;
	$this->{is_error} = shift;

	$this->{template_vars}{'status'} = $status;
}




=head3 C<set_status_redirect($status, $is_error)>

Set status description

=head4 Parameters

=over

=item C<$status>

Description of the status

=item C<$is_error>

true, if the status is to be treated as error

=back

=head4 Description

Sets the status description of the last action. If the session is loaded the
next time, C<set_status($status, $is_error)> will be called.

=cut

sub set_status_redirect {
	my $this = shift;
	my $status = shift;
	my $is_error = shift;

	$this->{session}->param('statusredirect', $status);
	$this->{session}->param('statusredirectiserror', $is_error);
}




=head3 C<set_status_reload($status, $action, $intervall)>

Set status description

=head4 Parameters

=over

=item C<$status>

Description of the status

=item C<$action>

Action to reload

=item C<$intervall>

set the reload intervall to the specified amount of seconds

=back

=head4 Description

Sets the status description of the last action. The page has
a short lifetime and a busy symbol will be displayed.

=cut

sub set_status_reload {
	my $this = shift;
	my $status = shift;
	my $action = shift;
	my $intervall = shift;

	$this->{session}->set_var('statusreload', $status);
	$this->{session}->set_var('pagereload', $action);
	$this->{session}->set_var('statusreloadintervall', $intervall);
}




=head3 C<mark_input_error($input_name)>

Marks a user error at an <input> field

=head4 Parameters

=over

=item C<$input_name>

The name of the <input> field

=back

=head4 Description

Marks an error at an input field. On the next invocation of C<print_page()>
the CSS-class of the <label> for the input field with the name C<$input_name>
will be set to C<error>.

=cut

sub mark_input_error {
	my $this = shift;

	my $input_id = shift;

	$input_id =~ s/[^A-Za-z0-9\-_:.]//g;
	$input_id =~ s/^([^A-Za-z])/x$1/;

	$this->{input_errors}{$input_id} = 1;
}




=head3 C<print_page($filename, $action, $textdomain)>

Output of an HTML page

=head4 Parameters

=over

=item C<$filename>

The filename of the template to be used relative to schulkonsole's
template directory.

=item C<$action>

The default action to be set in a <form> unless already specified.

=item C<$textdomain>

An additional msg catalog to be used for translations.

=back

=head4 Description

Prints an HTML page to standard output i.e. to the web-client. The filename
of the used template is relative to the schulkonsole's template directory
and may not contain the special directory C<..> in its path.

If there is a <form> in the template without or with an empty action
attribute, C<$action> is used instead.

The template variables set in this session will be used to produce the
output. For a description of the template format see Schulkonsole::Template.

=cut

sub print_page {
	my $this = shift;
	my $file = shift;
	my $action = shift;
	my $textdomain = shift;

	my $template = Template->new({
            ENCODING => 'utf8',
            INCLUDE_PATH => ['/usr/share/schulkonsole/tt','/usr/share/schulkonsole/css',
			    '/usr/share/schulkonsole/jquery'],
            WRAPPER => 'page.tt',
        });

	my $vars = $this->{template_vars};
	foreach my $key ($this->{query}->param) {
		$vars->{$key} = $this->{query}->param($key) unless defined $vars->{$key};
	}
	my $params = $this->{session}->dataref();
	foreach my $key (keys \%$params) {
            $vars->{$key} = $$params{$key} unless defined $vars->{$key};
    }
    $vars->{no_cookies} = $this->print_header();
    $vars->{parent_page} = $this->{parent_page};
	$vars->{is_error} = $this->{is_error};
	# localization: [% d.get('Text') %]
	$vars->{d} = $this->{d};
	$vars->{page}{textdomain} = $textdomain if defined $textdomain;
	$vars->{loc} = sub {
            my $stash = $template->context()->stash();
            my $textdomain = $stash->get(['page',0,'textdomain',0]);
            my $default = $stash->get(['page',0,'default',0]);
            
            return $vars->{d}{default}->get(@_) if $textdomain eq '';
            return $vars->{d}{default}->get(@_) unless $default eq '';
            return $vars->{d}{$textdomain}->get(@_) if defined $vars->{d}{$textdomain};

            return $vars->{d}{default}->get(@_);
        };
	$vars->{lang} = $this->{lang};
	$vars->{input_errors} = %{ $this->{input_errors} };
	$vars->{session_id} = $vars->{id};
    $vars->{action} = $action;
    if(defined $this->{dplugin}) {
        $vars->{dplugin} = $this->{dplugin};
    }
    # colored labels an Stelle von for="text" jetzt [% labelfor("text") %]
    $vars->{labelfor} = sub { return 'for="'.@_[0].'"'.($this->{input_errors}{@_[0]}? ' class="error"':''); };
    $vars->{dohref} = sub { return 'href="'.@_[0].($vars->{no_cookies}?'?'.CGI::Session->name().'='.$this->{session}->id.'"':'"'); };
    $vars->{dovalue} = sub { return 'value="' . $this->{query}->param(@_[0]) . '"'; };
    $vars->{valueof} = sub { return $this->{query}->param(@_[0]); };

	$template->process($file, $vars) or die "$0: " . $template->error()->as_string() . "!\n";

	# occasionally the session is not automatically flushed
	$this->{session}->flush();
}




=head3 C<exit_with_login_page($action)>

Output of an HTML page with a login form

=head4 Parameters

=over

=item C<$action>

The default action to be set in a <form> unless already specified.

=back

=head4 Description

Prints a login page to standard output i.e. to the web-client.

=cut

sub exit_with_login_page {
	my $this = shift;

	my $action = shift;

	# save query to load after re-authentication
	if ($this->{query}) {
		my $q = $this->{query};

		# do not save passwords or session-id in session
		$q->delete('oldpassword', 'newpassword', 'newpasswordagain');

		if ($q->param) {
			my $params = $q->Vars;
			$this->{session}->param('q', $params);

			$q->param('username', $this->{session}->param('username'));
		}
	}


	$this->set_var('version', $Schulkonsole::Config::_version);
	$this->print_page($Schulkonsole::Config::_login_template, $action);
	exit;
}




=head3 C<redirect($target)>

Print HTTP-redirect

=head4 Parameters

=over

=item C<$url>

The absolute URL of the target of the redirect

=back

=head4 Description

Prints a HTTP-header to standard output to redirect the web-client to
C<$url>.

=cut

sub redirect {
	my $this = shift;

	my $url = shift;


	if ($this->{key}) {
		my $cookie = $this->{query}->cookie(
			-name => 'key',
			-value => $this->{key},
			-path => $Schulkonsole::Config::_http_root,
			-secure => 1,
		);
		print $this->{query}->redirect( -cookie => $cookie,
		                                -uri => $url,
		                                -status => 303 );
	} else {
		print $this->{query}->redirect( -uri => $url,
		                                -status => 303 );
	}

	# occasionally the session is not automatically flushed
	$this->{session}->flush();

	exit;
}




=head3 C<save_password($password)>

Saves a password in the session

=head4 Parameters

=over

=item C<$password>

The password to be saved

=back

=head4 Description

Creates a random MD5-key and uses this key to encrypt C<$password> using
the Rijndael algorithm (aka AES). The result is stored in the session. The
key is transmitted to the client with the next HTML-page.

=cut

sub save_password {
	my $this = shift;
	my $password = shift;

	$this->{password} = $password;


	utf8::encode($password);

	my $iv = substr(Digest::MD5::md5_hex(rand(10000), time, $$),1,16);
	my $key = Digest::MD5::md5_hex(rand(10000), time, $$);
	my $cipher = Crypt::CBC->new(
                        -literal_key    => 1,
                        -key            => $key,
                        -header         => 'none',
                        -iv             => $iv,
                        -padding        => 'null',
                        -cipher         => 'Crypt::Rijndael');

	my $encrypted_password = $cipher->encrypt($password);
        my $encrypted_block = unpack( 'H*', $iv . $encrypted_password );
	$this->{key} = unpack( 'H*', $key );
	$this->{session}->param('password', $encrypted_block);
	$this->{session}->expire('password', $Schulkonsole::Config::_max_idle_time);
}




=head3 C<get_password()>

Get the user's password

=head4 Return value

The password or C<undef> if the password could not be restored

=head4 Description

Restores the password from the encrypted version saved in the session and
the key submitted by the user.

=cut

sub get_password {
	my $this = shift;

	return $this->{password} if exists $this->{password};

	my $key = $this->{query}->cookie('key');
	$key = $this->{query}->param('key') unless $key;
	my $encrypted_block = $this->{session}->param('password');
	if ($key and $encrypted_block) {
                my ($iv, $encrypted_password) = unpack( 'a16a*', pack( 'H*', $encrypted_block ) );
                my $cipher = Crypt::CBC->new(
                                -literal_key    => 1,
                                -key            => pack( 'H*', $key),
                                -header         => 'none',
                                -iv             => $iv,
                                -padding        => 'null',
                                -cipher         => 'Crypt::Rijndael');
		my $password = $cipher->decrypt($encrypted_password);

		utf8::decode($password);

		$this->{password} = $password;
	} else {
		$this->{password} = undef;
	}

	return $this->{password};
}



=head3 C<userdata($key)>

Get the value of a column of the current table of user data

=head4 Parameters

=over

=item C<$key>

The name of the column

=back

=head4 Return value

The value of the column

=head4 Description

Returns the value of column C<$key> from the table row with user data of the
session's user.

=cut

sub userdata {
	my $this = shift;
	my $key = shift;

	return $this->{userdata}{$key};
}




=head3 C<groups()>

Returns the groups of the current user

=head4 Return value

A Hash with the groupname as key and the id of the group's DB entry as value

=head4 Description


=cut

sub groups {
	my $this = shift;

	return $this->{groups};
}




=head3 C<query()>

Get the CGI-object of this session

=head4 Return value

An object of type CGI

=head4 Description

Returns the CGI-object which was created from the transmitted query data at
the beginning of the program run.

=cut

sub query {
	my $this = shift;

	return $this->{query};
}



=head3 C<q_param($key)>

Get parameter from CGI-object of this session

=head4 Parameters

=over

=item C<$key>

parameter name

=back

=head4 Return value

Value of parameter

=head4 Description

Returns parameter value of CGI-object that was created from the transmitted 
query data at the beginning of the program run.

=head3 C<q_param($key, $value)>

Set parameter in CGI-object of this session

=head4 Parameters

=over

=item C<$key>

parameter name

=item C<$value>

parameter value

=back

=head4 Description

Set parameter value in CGI-object that was created from the transmitted 
query data at the beginning of the program run.

=cut

sub q_param {
	my $this = shift;

	my $key = shift;
	my $value = shift;
	utf8::encode($key);

	if (defined $value) {
		$this->{query}->param($key, $value);
	} else {
		my $param = $this->{query}->param($key);
		utf8::decode($param);

		return $param;
	}
}




=head3 C<d($textdomain)>

Get the Locale::gettext-object of this session

=head4 Parameter 

=item C<$textdomain>

Optional parameter use C<$textdomain>

=head4 Return value

An object of type Locale::gettext

=head4 Description

Returns a Locale::gettext-object which is set to the user's most preferred
and available language.

=cut

sub d {
	my $this = shift;
	my $textdomain = shift;

	return $this->{d}{default} unless defined $textdomain;
	return $this->{d}{$textdomain} if defined $this->{d}{$textdomain};

	$this->{d}{$textdomain} = Locale::gettext->domain($textdomain);
	$this->{d}{$textdomain}->dir('/usr/share/locale');
	return $this->{d}{$textdomain};
}





=head3 C<read_groups_from_db()>

=head4 Description

(Re-)reads the user's groups from the database
and available language.

=cut

sub read_groups_from_db {
	my $this = shift;

	$this->{groups} = Schulkonsole::DB::user_groups(
		${ $this->{userdata} }{uidnumber},
		${ $this->{userdata} }{gidnumber},
		${ $this->{userdata} }{gid});
}




=head3 C<standard_error_handling($@)>

Do common error handling

=head4 Parameters

=over

=item C<$page>

Page to display when password has been verified

=item C<$@>

A Schulkonsole::Error object

=item C<do_redirect>

True if the user client will be re-directed after an error

=back

=head4 Description

Does standard error handling with a Schulkonsole::Error object

=cut

sub standard_error_handling {
	my $this = shift;
	my $page = shift;
	my $error = shift;
	my $do_redirect = shift;

	my $error_str;
	if (ref $error) {
		# password changed -> re-authenticate
		if (   $error->{code} == Schulkonsole::Error::Error::WRAPPER_UNAUTHENTICATED_ID) {
			$this->exit_with_login_page($page);
		}

		if ($error->{internal}) {
			$error_str = $this->d()->get('Interner Fehler');
			print STDERR $error;
		} else {
			$error_str = $error->what();
		}
	} else {
		$error_str = $error;
	}
	if ($do_redirect) {
		$this->set_status_redirect($error_str, 1);
	} else {
		$this->set_status($error_str, 1);
	}
	
	$this->print_page("$page.tt",$page);
}






=head3 C<session_id()>

Return the ID of this session

=head4 Description

Returns the ID of the CGI::Session.

=cut

sub session_id
{
	my $this = shift;

	return $this->{session}->id();
}




=head3 C<put_aside_session()>

Put the CGI::Session aside.

=head4 Description

Closes the CGI::Session and releases the lock. Use get_back_session() to
lock and load it again.

=cut

sub put_aside_session
{
	my $this = shift;

	$this->{session}->close();
	flock $this->{lock}, 8;
}



=head3 C<get_back_session()>

Get the CGI::Session back.

=head4 Description

Loads the CGI::Session after re-instating the lock.
Use after put_aside_session().

=cut

sub get_back_session
{
	my $this = shift;

	my $sid = $this->{session}->id();

	flock $this->{lock}, 2;

	$this->{session} = new CGI::Session("driver:File", $sid,
	   { Directory => $Schulkonsole::Config::_runtimedir });
}


#=head2 Private methods

sub init {
	my $this = shift;

	my $page = shift;
        my $plugin = shift;
        
	$this->{query} = new CGI;
	binmode STDOUT, ':encoding(UTF-8)';
	
	umask(umask() | 077);	# session-file mode 0600
	# create session from query to get the session id
	$this->{session} = new CGI::Session("driver:File", $this->{query},
	   { Directory => $Schulkonsole::Config::_runtimedir });
	my $sid = $this->{session}->id();
	$this->{session}->close();

	# lock session and re-open
	my $session_lockfile = Schulkonsole::Config::lockfile(
			'cgisession_' . $sid);
	open $this->{lock}, ">>$session_lockfile" or exit -106;
	flock $this->{lock}, 2;


	$this->{session} = new CGI::Session("driver:File", $sid,
	   { Directory => $Schulkonsole::Config::_runtimedir });


	$this->{session}->expire($Schulkonsole::Config::_login_expire_time)
		unless $this->{session}->param('session_start_time');

	# workaround: (CGI/Session.pm (Debian version 4.03-1) lines 582 and 671)
	# CGI::Session-module (4.03) does not provide _SESSION_REMOTE_ADDR if the
	# new session was created after loading an old session failed.
	# With -ip_match we cannot use this session.
	${ $this->{session}->{_DATA} }{_SESSION_REMOTE_ADDR} = $ENV{REMOTE_ADDR}
		unless    $this->{session}->param('_SESSION_REMOTE_ADDR')
		       or not defined $this->{session}->{_DATA};

	$this->{page} = $page;
        $this->{plugin} = $plugin;
        
	$this->init_l10n();

	$this->authenticate();

	if ($this->{session}->param('statusredirect')) {
		$this->set_status($this->{session}->param('statusredirect'), 
			$this->{session}->param('statusredirectiserror'));
		$this->{session}->clear('statusredirect');
		$this->{session}->clear('statusredirectiserror');
	} elsif ($this->{session}->param('statusbg')) {
		$this->set_status(
			  $this->{d}{default}->get('Ausgabe des Hintergrundprozess: ')
			. $this->{session}->param('statusbg'), 
		$this->{session}->param('statusbgiserror'));

		$this->{session}->clear('statusbg');
		$this->{session}->clear('statusbgiserror');
	}


	# set standard variables
	$this->set_var('version', $Schulkonsole::Config::_version);


	$this->set_var('username', ${ $this->{userdata} }{uid});
	$this->set_var('firstname', ${ $this->{userdata} }{firstname});
	$this->set_var('surname', ${ $this->{userdata} }{surname});

	$ENV{REMOTE_HOST} =
		gethostbyaddr(Socket::inet_aton($ENV{REMOTE_ADDR}), Socket::AF_INET)
		unless $ENV{REMOTE_HOST};

	my ($remote_room, $remote_workstation) = 
		Schulkonsole::Config::workstation_info($ENV{REMOTE_HOST},
		                                       $ENV{REMOTE_ADDR});
	$this->set_var('remote_room', $remote_room);
	$this->set_var('remote_workstation', $remote_workstation);

	$this->set_var('REMOTE_HOST', $ENV{REMOTE_HOST});
	$this->set_var('REMOTE_ADDR', $ENV{REMOTE_ADDR});
	$this->set_var('HTTP_HOST', $ENV{HTTP_HOST});
	$this->set_var('SERVER_ADDR', $ENV{SERVER_ADDR});
	$this->set_var('SERVER_NAME', $ENV{SERVER_NAME});

	$this->set_var('max_idle_time', $Schulkonsole::Config::_max_idle_time);

	my $max_idle_time_left = Schulkonsole::Config::expire_seconds(
		$Schulkonsole::Config::_max_idle_time);
	my $max_idle_hh = int($max_idle_time_left / 3600);
	$max_idle_time_left -= $max_idle_hh * 3600;
	my $max_idle_mm = int($max_idle_time_left / 60);
	my $max_idle_ss = $max_idle_time_left - $max_idle_mm * 60;
	my $max_idle_hh_mm_ss =
		sprintf("%d:%02d:%02d", $max_idle_hh, $max_idle_mm, $max_idle_ss);
	$this->set_var('max_idle_hh_mm_ss', $max_idle_hh_mm_ss);

	my $sec = $^T - $this->{session}->param('session_start_time');
	$sec = 0 if $sec < 0;
	my $hours = int($sec / 3600);
	$sec -= $hours * 3600;
	my $min = int($sec / 60);
	$sec -= $min * 60;
	$this->set_var('session_time', sprintf("%d:%02d:%02d", $hours, $min, $sec));
	
	# set menu access variables
	$this->set_var('quotaactivated',$Schulkonsole::SophomorixConfig::quotaactivated);
}




sub authenticate {
	my $this = shift;

	my $q = $this->{query};
	my $session = $this->{session};
	my $page = $this->{page};



	my $id = $session->param('id');
	if ($q->param('username')) { # user wants to authenticate
		my $username = $q->param('username');
		my $password = $q->param('password');


		utf8::decode($username);
		utf8::decode($password);

		$this->{userdata}
			= Schulkonsole::DB::verify_password($username, $password);
		if (defined $this->{userdata}) { # authentication succeeded

			my $session_username = $session->param('username');
			# same session, different user
			if (defined $session_username) {
				if ($session_username ne $username) {
					$session->clear;
					$session->param('username', $username);
				} elsif ($this->{session}->param('q')) {
					# load query from before session-timeout
					my $params = $this->{session}->param('q');
					foreach my $param (keys %$params) {
						$q->param($param, $$params{$param});
					}
					$this->{session}->clear('q');
				}
			} else {
				$session->param('username', $username);
			}


			$session->param('id', $this->{userdata}->{id});

			# force re-login after $...::_max_idle_time
			$session->expire('id'
				=> $Schulkonsole::Config::_max_idle_time);

			# expire session after $...::_session_expire_time idle-time
			$session->expire($Schulkonsole::Config::_session_expire_time);

			$session->param('session_start_time', $^T)
				unless $session->param('session_start_time');

			$this->save_password($password);


			$this->set_status($this->{d}{default}->get('Angemeldet'), 0);

		} else { # authentication failed
			$this->set_status($this->{d}{default}->get('Login fehlgeschlagen'), 1);
			$this->exit_with_login_page($page);
		}

	} elsif ($id) { # user already authenticated
		$this->{userdata} = Schulkonsole::DB::get_userdata_by_id($id);

	} else { # user needs to authenticate
		$this->exit_with_login_page($page);
	}


	# init permissions
	my $permissions = Schulkonsole::Config::permissions_pages();

	$this->read_groups_from_db();
	my @groupnames = keys %{ $this->{groups} };

	# FIXME: workaround for non existing students group!
	if(! (grep(/^teachers$/,@groupnames) or grep(/^domadmins$/,@groupnames))) {
		push @groupnames, 'students';
	}
	foreach my $group (('ALL', @groupnames)) {
		foreach my $page (keys %{ $$permissions{$group} }) {
			$this->{pages}{$page} = 1;
			$this->set_var('link_' . $page, 1);
		}
	}

	if (not $this->{pages}{$page}) {
		$this->set_status("$page: " . $this->{d}{default}->get('Zugriff verweigert'), 1);
		$this->exit_with_login_page($page);
	}


	my $groupname = join(', ', sort @groupnames);
	$groupname = $this->{d}{default}->get('Schueler') unless $groupname;
	$this->set_var('groupname', $groupname);

	my $parent_page = $page;
	$parent_page =~ s/^(.+?)_.*$/$1/;
	$this->{parent_page} = $parent_page;
}




sub init_l10n
{
	my $this = shift;

	my $session = $this->{session};
	my $plugin  = $this->{plugin};

	$this->{d}{default} = Locale::gettext->domain('schulkonsole');
	$this->{d}{default}->dir('/usr/share/locale');
        if(defined $plugin) {
            $this->{d}{$plugin} = Locale::gettext->domain($plugin);
            $this->{d}{$plugin}->dir('/usr/share/locale');
        }

	my $lang = 'C';
	if (defined $ENV{HTTP_ACCEPT_LANGUAGE}) {
		my %lang_map = (
			de_DE => 'C',	# default language, need not translate
			de => 'C',	# accept de for de_DE
			en => 'en_US.UTF-8',
			'*' => 'C',
		);
		foreach my $lang (sort {
				my ($a_q, $b_q);
				($a_q) = ($a =~ /;q=(\S+)/) or $a_q = 1.0;
				($b_q) = ($b =~ /;q=(\S+)/) or $b_q = 1.0;
				return $b_q <=> $a_q;
			} split /\s*,\s*/, $ENV{HTTP_ACCEPT_LANGUAGE}) {
			next if $lang =~ s/;q=(.*)$// and $1 == 0;

			if ($lang_map{$lang}) {
				$lang = $lang_map{$lang};
			} elsif (   $lang =~ s/^(..)-(..)$/$1_\U$2/
			         or $lang =~ s/^(..)$/$1_\U$1/) {
				$lang = $lang_map{$lang} if ($lang_map{$lang});
			}

			if ($lang eq 'C') {
				POSIX::setlocale(POSIX::LC_ALL, 'de_DE.UTF-8');
				last;
			}

			POSIX::setlocale(POSIX::LC_ALL, $lang);
			if ($this->{d}{default}->get('')) {
				($this->{'lang'}) = $lang =~ /^(..)/;
				last;
			}
		}
	}

	$this->set_var
}




1;
