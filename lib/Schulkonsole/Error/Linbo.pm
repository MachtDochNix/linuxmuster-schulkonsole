use strict;

package Schulkonsole::Error::Linbo;
require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = 0.16;
@ISA = qw(Exporter);
@EXPORT_OK = qw(
	OK

	START_CONF_ERROR

	WRAPPER_ERROR_BASE
	WRAPPER_GENERAL_ERROR
	WRAPPER_PROGRAM_ERROR
	WRAPPER_UNAUTHORIZED_UID
	WRAPPER_SCRIPT_EXEC_FAILED
	WRAPPER_UNAUTHENTICATED_ID
	WRAPPER_APP_ID_DOES_NOT_EXIST
	WRAPPER_UNAUTHORIZED_ID
	WRAPPER_INVALID_GROUP
	WRAPPER_INVALID_FILENAME
	WRAPPER_INVALID_IS_EXAMPLE
	WRAPPER_INVALID_IMAGE
	WRAPPER_INVALID_ACTION
	WRAPPER_CANNOT_OPEN_FILE
);

# package constants
use constant {
	OK => 0,

	START_CONF_ERROR => 50,

	WRAPPER_ERROR_BASE => 13000,
	WRAPPER_GENERAL_ERROR => 13000 -1,
	WRAPPER_PROGRAM_ERROR => 13000 -2,
	WRAPPER_UNAUTHORIZED_UID => 13000 -3,
	WRAPPER_SCRIPT_EXEC_FAILED => 13000 -6,
	WRAPPER_UNAUTHENTICATED_ID => 13000 -32,
	WRAPPER_APP_ID_DOES_NOT_EXIST => 13000 -33,
	WRAPPER_UNAUTHORIZED_ID => 13000 -34,
	WRAPPER_INVALID_GROUP => 13000 -55,
	WRAPPER_INVALID_FILENAME => 13000 -56,
	WRAPPER_INVALID_IS_EXAMPLE => 13000 -57,
	WRAPPER_INVALID_IMAGE => 13000 -58,
	WRAPPER_INVALID_ACTION => 13000 -59,
	WRAPPER_CANNOT_OPEN_FILE => 13000 -106,
};



1;