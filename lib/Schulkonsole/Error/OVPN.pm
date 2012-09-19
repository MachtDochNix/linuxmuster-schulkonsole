use strict;

package Schulkonsole::Error::OVPN;
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = 0.16;
@ISA = qw(Exporter);
@EXPORT_OK = qw(
	OK
	WRAPPER_ERROR_BASE
	WRAPPER_GENERAL_ERROR
	WRAPPER_PROGRAM_ERROR
	WRAPPER_UNAUTHORIZED_UID
	WRAPPER_SCRIPT_EXEC_FAILED
	WRAPPER_UNAUTHENTICATED_ID
	WRAPPER_APP_ID_DOES_NOT_EXIST
	WRAPPER_UNAUTHORIZED_ID
	WRAPPER_INVALID_PASSWORD
);

# package constants
use constant {
	OK => 0,

	WRAPPER_ERROR_BASE => 12000,
	WRAPPER_GENERAL_ERROR => 12000 -1,
	WRAPPER_PROGRAM_ERROR => 12000 -2,
	WRAPPER_UNAUTHORIZED_UID => 12000 -3,
	WRAPPER_SCRIPT_EXEC_FAILED => 12000 -6,
	WRAPPER_UNAUTHENTICATED_ID => 12000 -32,
	WRAPPER_APP_ID_DOES_NOT_EXIST => 12000 -33,
	WRAPPER_UNAUTHORIZED_ID => 12000 -34,
	WRAPPER_INVALID_PASSWORD => 12000 -97,
};



1;