use strict;
use utf8;
use Schulkonsole::Error;
use Schulkonsole::ExternalError;

use Sophomorix::SophomorixAPI;

package Schulkonsole::Wrapper;

sub new {
	my $class = shift;
    my $wrapcmd = shift;
    
	my $this = {
		wrapper_command => undef,
		app_id => shift,
		id => shift,
		password => shift,
		binaer => shift,
		in => undef,
		out => undef,
		err => undef,
		pid => undef,
		input_buffer => undef,
	};
	
	bless $this, $class;

	$this->init($wrapcmd);
	
	return $this;
}

sub buffer_input {
	my $this = shift;
    my $in = $this->{in};
    
	local $/ = undef if $this->{binaer};
	while (<$in>) {
		$this->{input_buffer} .= $_;
	}
}

sub init {
	my $this = shift;
	my $wrapcmd = shift;
	
	die new Schulkonsole::Error(
		Schulkonsole::Error::WRAPPER_WRONG,
		$wrapcmd, 1)
		unless $wrapcmd =~ /^\/usr\/lib\/schulkonsole\/bin\/wrapper-[a-z]{1,30}$/;
		
	$this->{wrapper_command} = $wrapcmd;
	die new Schulkonsole::Error(
		Schulkonsole::Error::WRAPPER_UNKNOWN,
		$wrapcmd, 1)
		unless $this->{wrapper_command};
}


sub start {
	my $this = shift;
	
	$this->{out} = *SCRIPTOUT;
	$this->{in} = *SCRIPTIN;
	$this->{err} = *SCRIPTIN;
	$this->{pid} = IPC::Open3::open3 $this->{out}, $this->{in}, $this->{err}, $this->{wrapper_command}
		or die new Schulkonsole::Error(
			Schulkonsole::Error::WRAPPER_EXEC_FAILED,
			$this->{wrapper_command}, $!);

	binmode $this->{out}, ':utf8';
	binmode $this->{in}, ':utf8';
	binmode $this->{err}, ':utf8';


	my $re = waitpid $this->{pid}, POSIX::WNOHANG;
	if (   $re == $this->{pid}
	    or $re == -1) {
		my $error = ($? >> 8) - 256;
		if ($error < -127) {
			die new Schulkonsole::Error(
				Schulkonsole::Error::WRAPPER_EXEC_FAILED,
				$this->{wrapper_command}, $!);
		} else {
			die new Schulkonsole::Error(
				Schulkonsole::Error::Sophomorix::WRAPPER_ERROR_BASE + $error,
				$this->{wrapper_command});
		}
	}

	print "$this->{out}" "$this->{id}\n$this->{password}\n$this->{app_id}\n";
}




sub stop {
	my $this = shift;

	my $re = waitpid $this->{pid}, 0;
	if (    ($re == $this->{pid} or $re == -1)
	    and $?) {
		my $error = ($? >> 8);
		if ($error <= 128) {
			die new Schulkonsole::ExternalError(
				Sophomorix::SophomorixAPI::fetch_error_string($error), 0,
				$this->{wrapper_command}, $!,
				($this->{input_buffer} ? "Output: $this->{input_buffer}" : 'No Output'));
		} else {
			$error -= 256;
			die new Schulkonsole::Error(
				Schulkonsole::Error::Sophomorix::WRAPPER_ERROR_BASE + $error,
				$this->{wrapper_command});
		}
	}

	if ($this->{out}) {
		close $this->{out}
			or die new Schulkonsole::Error(
				Schulkonsole::Error::WRAPPER_BROKEN_PIPE_OUT,
				$this->{wrapper_command}, $!,
				($this->{input_buffer} ? "Output: $this->{input_buffer}" : 'No Output'));
	}

	close $this->{in}
		or die new Schulkonsole::Error(
			Schulkonsole::Error::WRAPPER_BROKEN_PIPE_IN,
			$this->{wrapper_command}, $!,
			($this->{input_buffer} ? "Output: $this->{input_buffer}" : 'No Output'));

	undef $this->{input_buffer};
}

sub write {
	my $this = shift;
	my $string = shift;
	
	print($this->{out}, $string);
	
}

sub read {
	my $this = shift;
	$this->buffer_input();
	
	return $this->{input_buffer};
}


1;
