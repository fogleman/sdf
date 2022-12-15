####################################################################
#
#    This file was generated using Parse::Yapp version 1.05.
#
#        Don't edit this file, use source file instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
####################################################################
package ExtUtils::XSpp::Grammar;
use vars qw ( @ISA );
use strict;

@ISA= qw ( ExtUtils::XSpp::Grammar::YappDriver );
#Included Parse/Yapp/Driver.pm file----------------------------------------
{
#
# Module ExtUtils::XSpp::Grammar::YappDriver
#
# This module is part of the Parse::Yapp package available on your
# nearest CPAN
#
# Any use of this module in a standalone parser make the included
# text under the same copyright as the Parse::Yapp module itself.
#
# This notice should remain unchanged.
#
# (c) Copyright 1998-2001 Francois Desarmenien, all rights reserved.
# (see the pod text in Parse::Yapp module for use and distribution rights)
#

package ExtUtils::XSpp::Grammar::YappDriver;

require 5.004;

use strict;

use vars qw ( $VERSION $COMPATIBLE $FILENAME );

$VERSION = '1.05';
$COMPATIBLE = '0.07';
$FILENAME=__FILE__;

use Carp;

#Known parameters, all starting with YY (leading YY will be discarded)
my(%params)=(YYLEX => 'CODE', 'YYERROR' => 'CODE', YYVERSION => '',
			 YYRULES => 'ARRAY', YYSTATES => 'ARRAY', YYDEBUG => '');
#Mandatory parameters
my(@params)=('LEX','RULES','STATES');

sub new {
    my($class)=shift;
	my($errst,$nberr,$token,$value,$check,$dotpos);
    my($self)={ ERROR => \&_Error,
				ERRST => \$errst,
                NBERR => \$nberr,
				TOKEN => \$token,
				VALUE => \$value,
				DOTPOS => \$dotpos,
				STACK => [],
				DEBUG => 0,
				CHECK => \$check };

	_CheckParams( [], \%params, \@_, $self );

		exists($$self{VERSION})
	and	$$self{VERSION} < $COMPATIBLE
	and	croak "Yapp driver version $VERSION ".
			  "incompatible with version $$self{VERSION}:\n".
			  "Please recompile parser module.";

        ref($class)
    and $class=ref($class);

    bless($self,$class);
}

sub YYParse {
    my($self)=shift;
    my($retval);

	_CheckParams( \@params, \%params, \@_, $self );

	if($$self{DEBUG}) {
		_DBLoad();
		$retval = eval '$self->_DBParse()';#Do not create stab entry on compile
        $@ and die $@;
	}
	else {
		$retval = $self->_Parse();
	}
    $retval
}

sub YYData {
	my($self)=shift;

		exists($$self{USER})
	or	$$self{USER}={};

	$$self{USER};
	
}

sub YYErrok {
	my($self)=shift;

	${$$self{ERRST}}=0;
    undef;
}

sub YYNberr {
	my($self)=shift;

	${$$self{NBERR}};
}

sub YYRecovering {
	my($self)=shift;

	${$$self{ERRST}} != 0;
}

sub YYAbort {
	my($self)=shift;

	${$$self{CHECK}}='ABORT';
    undef;
}

sub YYAccept {
	my($self)=shift;

	${$$self{CHECK}}='ACCEPT';
    undef;
}

sub YYError {
	my($self)=shift;

	${$$self{CHECK}}='ERROR';
    undef;
}

sub YYSemval {
	my($self)=shift;
	my($index)= $_[0] - ${$$self{DOTPOS}} - 1;

		$index < 0
	and	-$index <= @{$$self{STACK}}
	and	return $$self{STACK}[$index][1];

	undef;	#Invalid index
}

sub YYCurtok {
	my($self)=shift;

        @_
    and ${$$self{TOKEN}}=$_[0];
    ${$$self{TOKEN}};
}

sub YYCurval {
	my($self)=shift;

        @_
    and ${$$self{VALUE}}=$_[0];
    ${$$self{VALUE}};
}

sub YYExpect {
    my($self)=shift;

    keys %{$self->{STATES}[$self->{STACK}[-1][0]]{ACTIONS}}
}

sub YYLexer {
    my($self)=shift;

	$$self{LEX};
}


#################
# Private stuff #
#################


sub _CheckParams {
	my($mandatory,$checklist,$inarray,$outhash)=@_;
	my($prm,$value);
	my($prmlst)={};

	while(($prm,$value)=splice(@$inarray,0,2)) {
        $prm=uc($prm);
			exists($$checklist{$prm})
		or	croak("Unknow parameter '$prm'");
			ref($value) eq $$checklist{$prm}
		or	croak("Invalid value for parameter '$prm'");
        $prm=unpack('@2A*',$prm);
		$$outhash{$prm}=$value;
	}
	for (@$mandatory) {
			exists($$outhash{$_})
		or	croak("Missing mandatory parameter '".lc($_)."'");
	}
}

sub _Error {
	print "Parse error.\n";
}

sub _DBLoad {
	{
		no strict 'refs';

			exists(${__PACKAGE__.'::'}{_DBParse})#Already loaded ?
		and	return;
	}
	my($fname)=__FILE__;
	my(@drv);
	open(DRV,"<$fname") or die "Report this as a BUG: Cannot open $fname";
	while(<DRV>) {
                	/^\s*sub\s+_Parse\s*{\s*$/ .. /^\s*}\s*#\s*_Parse\s*$/
        	and     do {
                	s/^#DBG>//;
                	push(@drv,$_);
        	}
	}
	close(DRV);

	$drv[0]=~s/_P/_DBP/;
	eval join('',@drv);
}

#Note that for loading debugging version of the driver,
#this file will be parsed from 'sub _Parse' up to '}#_Parse' inclusive.
#So, DO NOT remove comment at end of sub !!!
sub _Parse {
    my($self)=shift;

	my($rules,$states,$lex,$error)
     = @$self{ 'RULES', 'STATES', 'LEX', 'ERROR' };
	my($errstatus,$nberror,$token,$value,$stack,$check,$dotpos)
     = @$self{ 'ERRST', 'NBERR', 'TOKEN', 'VALUE', 'STACK', 'CHECK', 'DOTPOS' };

#DBG>	my($debug)=$$self{DEBUG};
#DBG>	my($dbgerror)=0;

#DBG>	my($ShowCurToken) = sub {
#DBG>		my($tok)='>';
#DBG>		for (split('',$$token)) {
#DBG>			$tok.=		(ord($_) < 32 or ord($_) > 126)
#DBG>					?	sprintf('<%02X>',ord($_))
#DBG>					:	$_;
#DBG>		}
#DBG>		$tok.='<';
#DBG>	};

	$$errstatus=0;
	$$nberror=0;
	($$token,$$value)=(undef,undef);
	@$stack=( [ 0, undef ] );
	$$check='';

    while(1) {
        my($actions,$act,$stateno);

        $stateno=$$stack[-1][0];
        $actions=$$states[$stateno];

#DBG>	print STDERR ('-' x 40),"\n";
#DBG>		$debug & 0x2
#DBG>	and	print STDERR "In state $stateno:\n";
#DBG>		$debug & 0x08
#DBG>	and	print STDERR "Stack:[".
#DBG>					 join(',',map { $$_[0] } @$stack).
#DBG>					 "]\n";


        if  (exists($$actions{ACTIONS})) {

				defined($$token)
            or	do {
				($$token,$$value)=&$lex($self);
#DBG>				$debug & 0x01
#DBG>			and	print STDERR "Need token. Got ".&$ShowCurToken."\n";
			};

            $act=   exists($$actions{ACTIONS}{$$token})
                    ?   $$actions{ACTIONS}{$$token}
                    :   exists($$actions{DEFAULT})
                        ?   $$actions{DEFAULT}
                        :   undef;
        }
        else {
            $act=$$actions{DEFAULT};
#DBG>			$debug & 0x01
#DBG>		and	print STDERR "Don't need token.\n";
        }

            defined($act)
        and do {

                $act > 0
            and do {        #shift

#DBG>				$debug & 0x04
#DBG>			and	print STDERR "Shift and go to state $act.\n";

					$$errstatus
				and	do {
					--$$errstatus;

#DBG>					$debug & 0x10
#DBG>				and	$dbgerror
#DBG>				and	$$errstatus == 0
#DBG>				and	do {
#DBG>					print STDERR "**End of Error recovery.\n";
#DBG>					$dbgerror=0;
#DBG>				};
				};


                push(@$stack,[ $act, $$value ]);

					$$token ne ''	#Don't eat the eof
				and	$$token=$$value=undef;
                next;
            };

            #reduce
            my($lhs,$len,$code,@sempar,$semval);
            ($lhs,$len,$code)=@{$$rules[-$act]};

#DBG>			$debug & 0x04
#DBG>		and	$act
#DBG>		and	print STDERR "Reduce using rule ".-$act." ($lhs,$len): ";

                $act
            or  $self->YYAccept();

            $$dotpos=$len;

                unpack('A1',$lhs) eq '@'    #In line rule
            and do {
                    $lhs =~ /^\@[0-9]+\-([0-9]+)$/
                or  die "In line rule name '$lhs' ill formed: ".
                        "report it as a BUG.\n";
                $$dotpos = $1;
            };

            @sempar =       $$dotpos
                        ?   map { $$_[1] } @$stack[ -$$dotpos .. -1 ]
                        :   ();

            $semval = $code ? &$code( $self, @sempar )
                            : @sempar ? $sempar[0] : undef;

            splice(@$stack,-$len,$len);

                $$check eq 'ACCEPT'
            and do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Accept.\n";

				return($semval);
			};

                $$check eq 'ABORT'
            and	do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Abort.\n";

				return(undef);

			};

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Back to state $$stack[-1][0], then ";

                $$check eq 'ERROR'
            or  do {
#DBG>				$debug & 0x04
#DBG>			and	print STDERR 
#DBG>				    "go to state $$states[$$stack[-1][0]]{GOTOS}{$lhs}.\n";

#DBG>				$debug & 0x10
#DBG>			and	$dbgerror
#DBG>			and	$$errstatus == 0
#DBG>			and	do {
#DBG>				print STDERR "**End of Error recovery.\n";
#DBG>				$dbgerror=0;
#DBG>			};

			    push(@$stack,
                     [ $$states[$$stack[-1][0]]{GOTOS}{$lhs}, $semval ]);
                $$check='';
                next;
            };

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Forced Error recovery.\n";

            $$check='';

        };

        #Error
            $$errstatus
        or   do {

            $$errstatus = 1;
            &$error($self);
                $$errstatus # if 0, then YYErrok has been called
            or  next;       # so continue parsing

#DBG>			$debug & 0x10
#DBG>		and	do {
#DBG>			print STDERR "**Entering Error recovery.\n";
#DBG>			++$dbgerror;
#DBG>		};

            ++$$nberror;

        };

			$$errstatus == 3	#The next token is not valid: discard it
		and	do {
				$$token eq ''	# End of input: no hope
			and	do {
#DBG>				$debug & 0x10
#DBG>			and	print STDERR "**At eof: aborting.\n";
				return(undef);
			};

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Dicard invalid token ".&$ShowCurToken.".\n";

			$$token=$$value=undef;
		};

        $$errstatus=3;

		while(	  @$stack
			  and (		not exists($$states[$$stack[-1][0]]{ACTIONS})
			        or  not exists($$states[$$stack[-1][0]]{ACTIONS}{error})
					or	$$states[$$stack[-1][0]]{ACTIONS}{error} <= 0)) {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Pop state $$stack[-1][0].\n";

			pop(@$stack);
		}

			@$stack
		or	do {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**No state left on stack: aborting.\n";

			return(undef);
		};

		#shift the error token

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Shift \$error token and go to state ".
#DBG>						 $$states[$$stack[-1][0]]{ACTIONS}{error}.
#DBG>						 ".\n";

		push(@$stack, [ $$states[$$stack[-1][0]]{ACTIONS}{error}, undef ]);

    }

    #never reached
	croak("Error in driver logic. Please, report it as a BUG");

}#_Parse
#DO NOT remove comment

1;

}
#End of include--------------------------------------------------




sub new {
        my($class)=shift;
        ref($class)
    and $class=ref($class);

    my($self)=$class->SUPER::new( yyversion => '1.05',
                                  yystates =>
[
	{#State 0
		ACTIONS => {
			'ID' => 28,
			'p_typemap' => 4,
			'p_any' => 3,
			'OPSPECIAL' => 33,
			'COMMENT' => 7,
			'p_exceptionmap' => 36,
			"class" => 9,
			'RAW_CODE' => 37,
			"const" => 11,
			"int" => 40,
			'p_module' => 16,
			"enum" => 47,
			'p_package' => 46,
			'p_loadplugin' => 45,
			'PREPROCESSOR' => 17,
			"short" => 18,
			'p_file' => 49,
			"void" => 19,
			"unsigned" => 50,
			'p_name' => 21,
			'p_include' => 22,
			"long" => 23,
			'p__type' => 26,
			"char" => 27
		},
		GOTOS => {
			'perc_loadplugin' => 29,
			'class_name' => 1,
			'top_list' => 2,
			'perc_package' => 32,
			'function' => 31,
			'nconsttype' => 30,
			'_top' => 5,
			'looks_like_function' => 6,
			'exceptionmap' => 34,
			'special_block_start' => 35,
			'perc_name' => 8,
			'class_decl' => 38,
			'typemap' => 10,
			'enum' => 39,
			'decorate_class' => 12,
			'special_block' => 13,
			'perc_module' => 41,
			'type_name' => 14,
			'perc_file' => 44,
			'perc_any' => 43,
			'basic_type' => 42,
			'template' => 15,
			'looks_like_renamed_function' => 48,
			'top' => 20,
			'function_decl' => 51,
			'perc_include' => 52,
			'directive' => 53,
			'type' => 24,
			'class' => 25,
			'raw' => 54
		}
	},
	{#State 1
		ACTIONS => {
			'OPANG' => 55
		},
		DEFAULT => -133
	},
	{#State 2
		ACTIONS => {
			'ID' => 28,
			'' => 56,
			'p_typemap' => 4,
			'p_any' => 3,
			'OPSPECIAL' => 33,
			'COMMENT' => 7,
			'p_exceptionmap' => 36,
			"class" => 9,
			'RAW_CODE' => 37,
			"const" => 11,
			"int" => 40,
			'p_module' => 16,
			"enum" => 47,
			'p_package' => 46,
			'p_loadplugin' => 45,
			'PREPROCESSOR' => 17,
			"short" => 18,
			'p_file' => 49,
			"void" => 19,
			"unsigned" => 50,
			'p_name' => 21,
			'p_include' => 22,
			"long" => 23,
			"char" => 27
		},
		GOTOS => {
			'perc_loadplugin' => 29,
			'class_name' => 1,
			'function' => 31,
			'perc_package' => 32,
			'nconsttype' => 30,
			'_top' => 5,
			'looks_like_function' => 6,
			'exceptionmap' => 34,
			'special_block_start' => 35,
			'perc_name' => 8,
			'class_decl' => 38,
			'typemap' => 10,
			'enum' => 39,
			'decorate_class' => 12,
			'special_block' => 13,
			'perc_module' => 41,
			'type_name' => 14,
			'perc_file' => 44,
			'perc_any' => 43,
			'basic_type' => 42,
			'template' => 15,
			'looks_like_renamed_function' => 48,
			'top' => 57,
			'function_decl' => 51,
			'perc_include' => 52,
			'directive' => 53,
			'type' => 24,
			'class' => 25,
			'raw' => 54
		}
	},
	{#State 3
		ACTIONS => {
			'OPSPECIAL' => 33,
			'OPCURLY' => 58
		},
		DEFAULT => -122,
		GOTOS => {
			'special_block' => 59,
			'special_block_start' => 35
		}
	},
	{#State 4
		ACTIONS => {
			'OPCURLY' => 60
		}
	},
	{#State 5
		DEFAULT => -4
	},
	{#State 6
		DEFAULT => -86
	},
	{#State 7
		DEFAULT => -27
	},
	{#State 8
		ACTIONS => {
			'ID' => 28,
			"class" => 9,
			"short" => 18,
			"void" => 19,
			"unsigned" => 50,
			"const" => 11,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'looks_like_function' => 61,
			'class_decl' => 62,
			'type' => 24
		}
	},
	{#State 9
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 63
		}
	},
	{#State 10
		DEFAULT => -16
	},
	{#State 11
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 64,
			'template' => 15
		}
	},
	{#State 12
		ACTIONS => {
			'SEMICOLON' => 65
		}
	},
	{#State 13
		DEFAULT => -29
	},
	{#State 14
		DEFAULT => -131
	},
	{#State 15
		DEFAULT => -132
	},
	{#State 16
		ACTIONS => {
			'OPCURLY' => 66
		}
	},
	{#State 17
		DEFAULT => -28
	},
	{#State 18
		ACTIONS => {
			"int" => 67
		},
		DEFAULT => -141
	},
	{#State 19
		DEFAULT => -135
	},
	{#State 20
		DEFAULT => -1
	},
	{#State 21
		ACTIONS => {
			'OPCURLY' => 68
		}
	},
	{#State 22
		ACTIONS => {
			'OPCURLY' => 69
		}
	},
	{#State 23
		ACTIONS => {
			"int" => 70
		},
		DEFAULT => -140
	},
	{#State 24
		ACTIONS => {
			'ID' => 71
		}
	},
	{#State 25
		DEFAULT => -6
	},
	{#State 26
		ACTIONS => {
			'OPCURLY' => 72
		}
	},
	{#State 27
		DEFAULT => -138
	},
	{#State 28
		ACTIONS => {
			'DCOLON' => 74
		},
		DEFAULT => -147,
		GOTOS => {
			'class_suffix' => 73
		}
	},
	{#State 29
		ACTIONS => {
			'SEMICOLON' => 75
		}
	},
	{#State 30
		ACTIONS => {
			'AMP' => 76,
			'STAR' => 77
		},
		DEFAULT => -128
	},
	{#State 31
		DEFAULT => -9
	},
	{#State 32
		ACTIONS => {
			'SEMICOLON' => 78
		}
	},
	{#State 33
		DEFAULT => -184
	},
	{#State 34
		DEFAULT => -17
	},
	{#State 35
		ACTIONS => {
			'CLSPECIAL' => 79,
			'line' => 80
		},
		GOTOS => {
			'special_block_end' => 81,
			'lines' => 82
		}
	},
	{#State 36
		ACTIONS => {
			'OPCURLY' => 83
		}
	},
	{#State 37
		DEFAULT => -26
	},
	{#State 38
		ACTIONS => {
			'SEMICOLON' => 84
		}
	},
	{#State 39
		DEFAULT => -8
	},
	{#State 40
		DEFAULT => -139
	},
	{#State 41
		ACTIONS => {
			'SEMICOLON' => 85
		}
	},
	{#State 42
		DEFAULT => -134
	},
	{#State 43
		ACTIONS => {
			'SEMICOLON' => 86
		}
	},
	{#State 44
		ACTIONS => {
			'SEMICOLON' => 87
		}
	},
	{#State 45
		ACTIONS => {
			'OPCURLY' => 88
		}
	},
	{#State 46
		ACTIONS => {
			'OPCURLY' => 89
		}
	},
	{#State 47
		ACTIONS => {
			'ID' => 91,
			'OPCURLY' => 90
		}
	},
	{#State 48
		DEFAULT => -95,
		GOTOS => {
			'function_metadata' => 92
		}
	},
	{#State 49
		ACTIONS => {
			'OPCURLY' => 93
		}
	},
	{#State 50
		ACTIONS => {
			"short" => 18,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		DEFAULT => -136,
		GOTOS => {
			'basic_type' => 94
		}
	},
	{#State 51
		ACTIONS => {
			'SEMICOLON' => 95
		}
	},
	{#State 52
		ACTIONS => {
			'SEMICOLON' => 96
		}
	},
	{#State 53
		DEFAULT => -7
	},
	{#State 54
		DEFAULT => -5
	},
	{#State 55
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"const" => 11,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_list' => 98,
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'type' => 97
		}
	},
	{#State 56
		DEFAULT => 0
	},
	{#State 57
		DEFAULT => -2
	},
	{#State 58
		ACTIONS => {
			'ID' => 102,
			'p_any' => 99,
			'p_name' => 21
		},
		GOTOS => {
			'perc_name' => 101,
			'perc_any_arg' => 100,
			'perc_any_args' => 103
		}
	},
	{#State 59
		DEFAULT => -24,
		GOTOS => {
			'mixed_blocks' => 104
		}
	},
	{#State 60
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"const" => 11,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'type' => 105
		}
	},
	{#State 61
		DEFAULT => -87
	},
	{#State 62
		DEFAULT => -43
	},
	{#State 63
		ACTIONS => {
			'COLON' => 107
		},
		DEFAULT => -47,
		GOTOS => {
			'base_classes' => 106
		}
	},
	{#State 64
		ACTIONS => {
			'AMP' => 76,
			'STAR' => 77
		},
		DEFAULT => -127
	},
	{#State 65
		DEFAULT => -39
	},
	{#State 66
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 108
		}
	},
	{#State 67
		DEFAULT => -143
	},
	{#State 68
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 109
		}
	},
	{#State 69
		ACTIONS => {
			'ID' => 111,
			'DASH' => 112
		},
		GOTOS => {
			'file_name' => 110
		}
	},
	{#State 70
		DEFAULT => -142
	},
	{#State 71
		ACTIONS => {
			'OPPAR' => 113
		}
	},
	{#State 72
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"const" => 11,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'type' => 114
		}
	},
	{#State 73
		ACTIONS => {
			'DCOLON' => 115
		},
		DEFAULT => -148
	},
	{#State 74
		ACTIONS => {
			'ID' => 116
		}
	},
	{#State 75
		DEFAULT => -13
	},
	{#State 76
		DEFAULT => -130
	},
	{#State 77
		DEFAULT => -129
	},
	{#State 78
		DEFAULT => -11
	},
	{#State 79
		DEFAULT => -185
	},
	{#State 80
		DEFAULT => -186
	},
	{#State 81
		DEFAULT => -183
	},
	{#State 82
		ACTIONS => {
			'CLSPECIAL' => 79,
			'line' => 117
		},
		GOTOS => {
			'special_block_end' => 118
		}
	},
	{#State 83
		ACTIONS => {
			'ID' => 119
		}
	},
	{#State 84
		DEFAULT => -38
	},
	{#State 85
		DEFAULT => -10
	},
	{#State 86
		DEFAULT => -15
	},
	{#State 87
		DEFAULT => -12
	},
	{#State 88
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 120
		}
	},
	{#State 89
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 121
		}
	},
	{#State 90
		DEFAULT => -32,
		GOTOS => {
			'enum_element_list' => 122
		}
	},
	{#State 91
		ACTIONS => {
			'OPCURLY' => 123
		}
	},
	{#State 92
		ACTIONS => {
			'p_any' => 3,
			'p_alias' => 128,
			'p_code' => 131,
			'p_cleanup' => 125,
			'p_postcall' => 127,
			'p_catch' => 135
		},
		DEFAULT => -88,
		GOTOS => {
			'perc_postcall' => 130,
			'perc_code' => 124,
			'perc_any' => 132,
			'perc_cleanup' => 133,
			'perc_catch' => 126,
			'_function_metadata' => 134,
			'perc_alias' => 129
		}
	},
	{#State 93
		ACTIONS => {
			'ID' => 111,
			'DASH' => 112
		},
		GOTOS => {
			'file_name' => 136
		}
	},
	{#State 94
		DEFAULT => -137
	},
	{#State 95
		DEFAULT => -40
	},
	{#State 96
		DEFAULT => -14
	},
	{#State 97
		DEFAULT => -145
	},
	{#State 98
		ACTIONS => {
			'CLANG' => 137,
			'COMMA' => 138
		}
	},
	{#State 99
		DEFAULT => -24,
		GOTOS => {
			'mixed_blocks' => 139
		}
	},
	{#State 100
		DEFAULT => -123
	},
	{#State 101
		ACTIONS => {
			'SEMICOLON' => 140
		}
	},
	{#State 102
		ACTIONS => {
			'CLCURLY' => 141
		}
	},
	{#State 103
		ACTIONS => {
			'p_any' => 99,
			'p_name' => 21,
			'CLCURLY' => 143
		},
		GOTOS => {
			'perc_name' => 101,
			'perc_any_arg' => 142
		}
	},
	{#State 104
		ACTIONS => {
			'OPSPECIAL' => 33,
			'OPCURLY' => 144
		},
		DEFAULT => -121,
		GOTOS => {
			'simple_block' => 146,
			'special_block' => 145,
			'special_block_start' => 35
		}
	},
	{#State 105
		ACTIONS => {
			'CLCURLY' => 147
		}
	},
	{#State 106
		ACTIONS => {
			'COMMA' => 149
		},
		DEFAULT => -55,
		GOTOS => {
			'class_metadata' => 148
		}
	},
	{#State 107
		ACTIONS => {
			"protected" => 153,
			"private" => 152,
			"public" => 150
		},
		GOTOS => {
			'base_class' => 151
		}
	},
	{#State 108
		ACTIONS => {
			'CLCURLY' => 154
		}
	},
	{#State 109
		ACTIONS => {
			'CLCURLY' => 155
		}
	},
	{#State 110
		ACTIONS => {
			'CLCURLY' => 156
		}
	},
	{#State 111
		ACTIONS => {
			'DOT' => 158,
			'SLASH' => 157
		}
	},
	{#State 112
		DEFAULT => -153
	},
	{#State 113
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 160,
			"unsigned" => 50,
			"const" => 11,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		DEFAULT => -160,
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'nonvoid_arg_list' => 159,
			'arg_list' => 162,
			'argument' => 163,
			'type' => 161
		}
	},
	{#State 114
		ACTIONS => {
			'CLCURLY' => 164
		}
	},
	{#State 115
		ACTIONS => {
			'ID' => 165
		}
	},
	{#State 116
		DEFAULT => -151
	},
	{#State 117
		DEFAULT => -187
	},
	{#State 118
		DEFAULT => -182
	},
	{#State 119
		ACTIONS => {
			'CLCURLY' => 166
		}
	},
	{#State 120
		ACTIONS => {
			'CLCURLY' => 167
		}
	},
	{#State 121
		ACTIONS => {
			'CLCURLY' => 168
		}
	},
	{#State 122
		ACTIONS => {
			'ID' => 169,
			'PREPROCESSOR' => 17,
			'RAW_CODE' => 37,
			'OPSPECIAL' => 33,
			'COMMENT' => 7,
			'CLCURLY' => 171
		},
		GOTOS => {
			'enum_element' => 170,
			'special_block' => 13,
			'raw' => 172,
			'special_block_start' => 35
		}
	},
	{#State 123
		DEFAULT => -32,
		GOTOS => {
			'enum_element_list' => 173
		}
	},
	{#State 124
		DEFAULT => -102
	},
	{#State 125
		ACTIONS => {
			'OPSPECIAL' => 33
		},
		GOTOS => {
			'special_block' => 174,
			'special_block_start' => 35
		}
	},
	{#State 126
		DEFAULT => -105
	},
	{#State 127
		ACTIONS => {
			'OPSPECIAL' => 33
		},
		GOTOS => {
			'special_block' => 175,
			'special_block_start' => 35
		}
	},
	{#State 128
		ACTIONS => {
			'OPCURLY' => 176
		}
	},
	{#State 129
		DEFAULT => -106
	},
	{#State 130
		DEFAULT => -104
	},
	{#State 131
		ACTIONS => {
			'OPSPECIAL' => 33
		},
		GOTOS => {
			'special_block' => 177,
			'special_block_start' => 35
		}
	},
	{#State 132
		DEFAULT => -107
	},
	{#State 133
		DEFAULT => -103
	},
	{#State 134
		DEFAULT => -94
	},
	{#State 135
		ACTIONS => {
			'OPCURLY' => 178
		}
	},
	{#State 136
		ACTIONS => {
			'CLCURLY' => 179
		}
	},
	{#State 137
		DEFAULT => -144
	},
	{#State 138
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"const" => 11,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'type' => 180
		}
	},
	{#State 139
		ACTIONS => {
			'OPCURLY' => 144,
			'OPSPECIAL' => 33,
			'SEMICOLON' => 181
		},
		GOTOS => {
			'simple_block' => 146,
			'special_block' => 145,
			'special_block_start' => 35
		}
	},
	{#State 140
		DEFAULT => -126
	},
	{#State 141
		DEFAULT => -24,
		GOTOS => {
			'mixed_blocks' => 182
		}
	},
	{#State 142
		DEFAULT => -124
	},
	{#State 143
		DEFAULT => -119
	},
	{#State 144
		ACTIONS => {
			'ID' => 183
		}
	},
	{#State 145
		DEFAULT => -22
	},
	{#State 146
		DEFAULT => -23
	},
	{#State 147
		ACTIONS => {
			'OPCURLY' => 184,
			'SEMICOLON' => 185
		}
	},
	{#State 148
		ACTIONS => {
			'OPCURLY' => 186,
			'p_any' => 3,
			'p_catch' => 135
		},
		GOTOS => {
			'perc_any' => 188,
			'perc_catch' => 187
		}
	},
	{#State 149
		ACTIONS => {
			"protected" => 153,
			"private" => 152,
			"public" => 150
		},
		GOTOS => {
			'base_class' => 189
		}
	},
	{#State 150
		ACTIONS => {
			'ID' => 28,
			'p_name' => 21
		},
		GOTOS => {
			'perc_name' => 191,
			'class_name' => 190,
			'class_name_rename' => 192
		}
	},
	{#State 151
		DEFAULT => -45
	},
	{#State 152
		ACTIONS => {
			'ID' => 28,
			'p_name' => 21
		},
		GOTOS => {
			'perc_name' => 191,
			'class_name' => 190,
			'class_name_rename' => 193
		}
	},
	{#State 153
		ACTIONS => {
			'ID' => 28,
			'p_name' => 21
		},
		GOTOS => {
			'perc_name' => 191,
			'class_name' => 190,
			'class_name_rename' => 194
		}
	},
	{#State 154
		DEFAULT => -111
	},
	{#State 155
		DEFAULT => -108
	},
	{#State 156
		DEFAULT => -114
	},
	{#State 157
		ACTIONS => {
			'ID' => 111,
			'DASH' => 112
		},
		GOTOS => {
			'file_name' => 195
		}
	},
	{#State 158
		ACTIONS => {
			'ID' => 196
		}
	},
	{#State 159
		ACTIONS => {
			'COMMA' => 197
		},
		DEFAULT => -156
	},
	{#State 160
		ACTIONS => {
			'CLPAR' => -157
		},
		DEFAULT => -135
	},
	{#State 161
		ACTIONS => {
			'ID' => 199,
			'p_length' => 198
		}
	},
	{#State 162
		ACTIONS => {
			'CLPAR' => 200
		}
	},
	{#State 163
		DEFAULT => -158
	},
	{#State 164
		DEFAULT => -3
	},
	{#State 165
		DEFAULT => -152
	},
	{#State 166
		ACTIONS => {
			'OPCURLY' => 201
		}
	},
	{#State 167
		DEFAULT => -113
	},
	{#State 168
		DEFAULT => -110
	},
	{#State 169
		ACTIONS => {
			'EQUAL' => 202
		},
		DEFAULT => -35
	},
	{#State 170
		ACTIONS => {
			'COMMA' => 203
		},
		DEFAULT => -33
	},
	{#State 171
		ACTIONS => {
			'SEMICOLON' => 204
		}
	},
	{#State 172
		DEFAULT => -37
	},
	{#State 173
		ACTIONS => {
			'ID' => 169,
			'PREPROCESSOR' => 17,
			'RAW_CODE' => 37,
			'OPSPECIAL' => 33,
			'COMMENT' => 7,
			'CLCURLY' => 205
		},
		GOTOS => {
			'enum_element' => 170,
			'special_block' => 13,
			'raw' => 172,
			'special_block_start' => 35
		}
	},
	{#State 174
		DEFAULT => -116
	},
	{#State 175
		DEFAULT => -117
	},
	{#State 176
		ACTIONS => {
			'ID' => 206
		}
	},
	{#State 177
		DEFAULT => -115
	},
	{#State 178
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 207,
			'class_name_list' => 208
		}
	},
	{#State 179
		DEFAULT => -112
	},
	{#State 180
		DEFAULT => -146
	},
	{#State 181
		DEFAULT => -125
	},
	{#State 182
		ACTIONS => {
			'OPSPECIAL' => 33,
			'OPCURLY' => 144
		},
		DEFAULT => -120,
		GOTOS => {
			'simple_block' => 146,
			'special_block' => 145,
			'special_block_start' => 35
		}
	},
	{#State 183
		ACTIONS => {
			'CLCURLY' => 209
		}
	},
	{#State 184
		ACTIONS => {
			'ID' => 210
		}
	},
	{#State 185
		DEFAULT => -20
	},
	{#State 186
		DEFAULT => -56,
		GOTOS => {
			'class_body_list' => 211
		}
	},
	{#State 187
		DEFAULT => -53
	},
	{#State 188
		DEFAULT => -54
	},
	{#State 189
		DEFAULT => -46
	},
	{#State 190
		DEFAULT => -51
	},
	{#State 191
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 212
		}
	},
	{#State 192
		DEFAULT => -48
	},
	{#State 193
		DEFAULT => -50
	},
	{#State 194
		DEFAULT => -49
	},
	{#State 195
		DEFAULT => -155
	},
	{#State 196
		DEFAULT => -154
	},
	{#State 197
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"const" => 11,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'argument' => 213,
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'type' => 161
		}
	},
	{#State 198
		ACTIONS => {
			'OPCURLY' => 214
		}
	},
	{#State 199
		DEFAULT => -162,
		GOTOS => {
			'argument_metadata' => 215
		}
	},
	{#State 200
		ACTIONS => {
			"const" => 216
		},
		DEFAULT => -80,
		GOTOS => {
			'const' => 217
		}
	},
	{#State 201
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 219,
			'class_name' => 218,
			'basic_type' => 42
		}
	},
	{#State 202
		ACTIONS => {
			'ID' => 28,
			'INTEGER' => 222,
			'QUOTED_STRING' => 224,
			'DASH' => 226,
			'FLOAT' => 225
		},
		GOTOS => {
			'class_name' => 220,
			'value' => 223,
			'expression' => 221
		}
	},
	{#State 203
		DEFAULT => -34
	},
	{#State 204
		DEFAULT => -30
	},
	{#State 205
		ACTIONS => {
			'SEMICOLON' => 227
		}
	},
	{#State 206
		ACTIONS => {
			'EQUAL' => 228
		}
	},
	{#State 207
		DEFAULT => -149
	},
	{#State 208
		ACTIONS => {
			'COMMA' => 229,
			'CLCURLY' => 230
		}
	},
	{#State 209
		DEFAULT => -25
	},
	{#State 210
		ACTIONS => {
			'CLCURLY' => 231
		}
	},
	{#State 211
		ACTIONS => {
			'ID' => 250,
			'p_typemap' => 4,
			'p_any' => 3,
			'OPSPECIAL' => 33,
			"virtual" => 251,
			'COMMENT' => 7,
			"class_static" => 233,
			"package_static" => 252,
			"public" => 234,
			'p_exceptionmap' => 36,
			'RAW_CODE' => 37,
			"const" => 11,
			"static" => 256,
			"int" => 40,
			"private" => 240,
			'CLCURLY' => 259,
			'PREPROCESSOR' => 17,
			"short" => 18,
			"void" => 19,
			"unsigned" => 50,
			'p_name' => 21,
			'TILDE' => 244,
			"protected" => 245,
			"long" => 23,
			"char" => 27
		},
		DEFAULT => -71,
		GOTOS => {
			'class_name' => 1,
			'nconsttype' => 30,
			'looks_like_function' => 6,
			'static' => 232,
			'exceptionmap' => 253,
			'special_block_start' => 35,
			'perc_name' => 235,
			'looks_like_member' => 236,
			'typemap' => 237,
			'class_body_element' => 254,
			'method' => 255,
			'special_block' => 13,
			'vmethod' => 238,
			'nmethod' => 239,
			'access_specifier' => 241,
			'type_name' => 14,
			'ctor' => 242,
			'perc_any' => 257,
			'basic_type' => 42,
			'template' => 15,
			'member' => 243,
			'virtual' => 258,
			'looks_like_renamed_function' => 260,
			'_vmethod' => 261,
			'dtor' => 246,
			'type' => 247,
			'raw' => 262,
			'method_decl' => 249,
			'member_decl' => 248
		}
	},
	{#State 212
		DEFAULT => -52
	},
	{#State 213
		DEFAULT => -159
	},
	{#State 214
		ACTIONS => {
			'ID' => 263
		}
	},
	{#State 215
		ACTIONS => {
			'EQUAL' => 264,
			'p_any' => 3
		},
		DEFAULT => -166,
		GOTOS => {
			'perc_any' => 266,
			'_argument_metadata' => 265
		}
	},
	{#State 216
		DEFAULT => -79
	},
	{#State 217
		DEFAULT => -85
	},
	{#State 218
		DEFAULT => -133
	},
	{#State 219
		ACTIONS => {
			'CLCURLY' => 267
		}
	},
	{#State 220
		ACTIONS => {
			'OPPAR' => 268
		},
		DEFAULT => -171
	},
	{#State 221
		DEFAULT => -36
	},
	{#State 222
		DEFAULT => -167
	},
	{#State 223
		ACTIONS => {
			'AMP' => 269,
			'PIPE' => 270
		},
		DEFAULT => -176
	},
	{#State 224
		DEFAULT => -170
	},
	{#State 225
		DEFAULT => -169
	},
	{#State 226
		ACTIONS => {
			'INTEGER' => 271
		}
	},
	{#State 227
		DEFAULT => -31
	},
	{#State 228
		ACTIONS => {
			'INTEGER' => 272
		}
	},
	{#State 229
		ACTIONS => {
			'ID' => 28
		},
		GOTOS => {
			'class_name' => 273
		}
	},
	{#State 230
		DEFAULT => -118
	},
	{#State 231
		ACTIONS => {
			'OPCURLY' => 274,
			'OPSPECIAL' => 33
		},
		DEFAULT => -181,
		GOTOS => {
			'special_blocks' => 276,
			'special_block' => 275,
			'special_block_start' => 35
		}
	},
	{#State 232
		ACTIONS => {
			'ID' => 28,
			"class_static" => 233,
			"package_static" => 252,
			"short" => 18,
			"void" => 19,
			"unsigned" => 50,
			"const" => 11,
			'p_name' => 21,
			"long" => 23,
			"static" => 256,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'looks_like_function' => 6,
			'static' => 232,
			'perc_name' => 277,
			'looks_like_renamed_function' => 260,
			'nmethod' => 278,
			'type' => 24
		}
	},
	{#State 233
		DEFAULT => -83
	},
	{#State 234
		ACTIONS => {
			'COLON' => 279
		}
	},
	{#State 235
		ACTIONS => {
			'ID' => 250,
			"virtual" => 251,
			"short" => 18,
			"void" => 19,
			"unsigned" => 50,
			"const" => 11,
			'p_name' => 21,
			'TILDE' => 244,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'ctor' => 283,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'looks_like_function' => 61,
			'virtual' => 258,
			'perc_name' => 280,
			'looks_like_member' => 281,
			'_vmethod' => 261,
			'dtor' => 284,
			'type' => 247,
			'vmethod' => 282
		}
	},
	{#State 236
		DEFAULT => -72
	},
	{#State 237
		DEFAULT => -60
	},
	{#State 238
		DEFAULT => -76
	},
	{#State 239
		DEFAULT => -75
	},
	{#State 240
		ACTIONS => {
			'COLON' => 285
		}
	},
	{#State 241
		DEFAULT => -62
	},
	{#State 242
		DEFAULT => -77
	},
	{#State 243
		DEFAULT => -63
	},
	{#State 244
		ACTIONS => {
			'ID' => 286
		}
	},
	{#State 245
		ACTIONS => {
			'COLON' => 287
		}
	},
	{#State 246
		DEFAULT => -78
	},
	{#State 247
		ACTIONS => {
			'ID' => 288
		}
	},
	{#State 248
		ACTIONS => {
			'SEMICOLON' => 289
		}
	},
	{#State 249
		ACTIONS => {
			'SEMICOLON' => 290
		}
	},
	{#State 250
		ACTIONS => {
			'DCOLON' => 74,
			'OPPAR' => 291
		},
		DEFAULT => -147,
		GOTOS => {
			'class_suffix' => 73
		}
	},
	{#State 251
		DEFAULT => -81
	},
	{#State 252
		DEFAULT => -82
	},
	{#State 253
		DEFAULT => -61
	},
	{#State 254
		DEFAULT => -57
	},
	{#State 255
		DEFAULT => -58
	},
	{#State 256
		DEFAULT => -84
	},
	{#State 257
		ACTIONS => {
			'SEMICOLON' => 292
		}
	},
	{#State 258
		ACTIONS => {
			'ID' => 28,
			"virtual" => 251,
			"short" => 18,
			"void" => 19,
			"unsigned" => 50,
			"const" => 11,
			'p_name' => 21,
			'TILDE' => 244,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'looks_like_function' => 293,
			'virtual' => 296,
			'perc_name' => 294,
			'type' => 24,
			'dtor' => 295
		}
	},
	{#State 259
		DEFAULT => -44
	},
	{#State 260
		DEFAULT => -95,
		GOTOS => {
			'function_metadata' => 297
		}
	},
	{#State 261
		DEFAULT => -98
	},
	{#State 262
		DEFAULT => -59
	},
	{#State 263
		ACTIONS => {
			'CLCURLY' => 298
		}
	},
	{#State 264
		ACTIONS => {
			'ID' => 28,
			'INTEGER' => 222,
			'QUOTED_STRING' => 224,
			'DASH' => 226,
			'FLOAT' => 225
		},
		GOTOS => {
			'class_name' => 220,
			'value' => 223,
			'expression' => 299
		}
	},
	{#State 265
		DEFAULT => -161
	},
	{#State 266
		DEFAULT => -163
	},
	{#State 267
		ACTIONS => {
			'OPCURLY' => 300
		}
	},
	{#State 268
		ACTIONS => {
			'ID' => 28,
			'INTEGER' => 222,
			'QUOTED_STRING' => 224,
			'FLOAT' => 225,
			'DASH' => 226
		},
		DEFAULT => -175,
		GOTOS => {
			'class_name' => 220,
			'value_list' => 301,
			'value' => 302
		}
	},
	{#State 269
		ACTIONS => {
			'ID' => 28,
			'INTEGER' => 222,
			'QUOTED_STRING' => 224,
			'DASH' => 226,
			'FLOAT' => 225
		},
		GOTOS => {
			'class_name' => 220,
			'value' => 303
		}
	},
	{#State 270
		ACTIONS => {
			'ID' => 28,
			'INTEGER' => 222,
			'QUOTED_STRING' => 224,
			'DASH' => 226,
			'FLOAT' => 225
		},
		GOTOS => {
			'class_name' => 220,
			'value' => 304
		}
	},
	{#State 271
		DEFAULT => -168
	},
	{#State 272
		ACTIONS => {
			'CLCURLY' => 305
		}
	},
	{#State 273
		DEFAULT => -150
	},
	{#State 274
		ACTIONS => {
			'p_any' => 99,
			'p_name' => 21
		},
		GOTOS => {
			'perc_name' => 101,
			'perc_any_arg' => 100,
			'perc_any_args' => 306
		}
	},
	{#State 275
		DEFAULT => -179
	},
	{#State 276
		ACTIONS => {
			'OPSPECIAL' => 33,
			'SEMICOLON' => 308
		},
		GOTOS => {
			'special_block' => 307,
			'special_block_start' => 35
		}
	},
	{#State 277
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 19,
			"const" => 11,
			"unsigned" => 50,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'looks_like_function' => 61,
			'type' => 24
		}
	},
	{#State 278
		DEFAULT => -97
	},
	{#State 279
		DEFAULT => -65
	},
	{#State 280
		ACTIONS => {
			'ID' => 309,
			'TILDE' => 244,
			'p_name' => 21,
			"virtual" => 251
		},
		GOTOS => {
			'perc_name' => 280,
			'ctor' => 283,
			'_vmethod' => 261,
			'dtor' => 284,
			'vmethod' => 282,
			'virtual' => 258
		}
	},
	{#State 281
		DEFAULT => -73
	},
	{#State 282
		DEFAULT => -99
	},
	{#State 283
		DEFAULT => -90
	},
	{#State 284
		DEFAULT => -92
	},
	{#State 285
		DEFAULT => -67
	},
	{#State 286
		ACTIONS => {
			'OPPAR' => 310
		}
	},
	{#State 287
		DEFAULT => -66
	},
	{#State 288
		ACTIONS => {
			'OPPAR' => 113
		},
		DEFAULT => -69,
		GOTOS => {
			'member_metadata' => 311
		}
	},
	{#State 289
		DEFAULT => -42
	},
	{#State 290
		DEFAULT => -41
	},
	{#State 291
		ACTIONS => {
			'ID' => 28,
			"short" => 18,
			"void" => 160,
			"unsigned" => 50,
			"const" => 11,
			"long" => 23,
			"int" => 40,
			"char" => 27
		},
		DEFAULT => -160,
		GOTOS => {
			'type_name' => 14,
			'class_name' => 1,
			'basic_type' => 42,
			'nconsttype' => 30,
			'template' => 15,
			'nonvoid_arg_list' => 159,
			'arg_list' => 312,
			'argument' => 163,
			'type' => 161
		}
	},
	{#State 292
		DEFAULT => -64
	},
	{#State 293
		ACTIONS => {
			'EQUAL' => 313
		},
		DEFAULT => -95,
		GOTOS => {
			'function_metadata' => 314
		}
	},
	{#State 294
		ACTIONS => {
			'TILDE' => 244,
			'p_name' => 21,
			"virtual" => 251
		},
		GOTOS => {
			'perc_name' => 294,
			'dtor' => 284,
			'virtual' => 296
		}
	},
	{#State 295
		DEFAULT => -93
	},
	{#State 296
		ACTIONS => {
			'TILDE' => 244,
			'p_name' => 21,
			"virtual" => 251
		},
		GOTOS => {
			'perc_name' => 294,
			'dtor' => 295,
			'virtual' => 296
		}
	},
	{#State 297
		ACTIONS => {
			'p_any' => 3,
			'p_alias' => 128,
			'p_code' => 131,
			'p_cleanup' => 125,
			'p_postcall' => 127,
			'p_catch' => 135
		},
		DEFAULT => -96,
		GOTOS => {
			'perc_postcall' => 130,
			'perc_code' => 124,
			'perc_any' => 132,
			'perc_cleanup' => 133,
			'perc_catch' => 126,
			'_function_metadata' => 134,
			'perc_alias' => 129
		}
	},
	{#State 298
		DEFAULT => -164
	},
	{#State 299
		DEFAULT => -165
	},
	{#State 300
		ACTIONS => {
			'ID' => 315
		}
	},
	{#State 301
		ACTIONS => {
			'CLPAR' => 316,
			'COMMA' => 317
		}
	},
	{#State 302
		DEFAULT => -173
	},
	{#State 303
		DEFAULT => -177
	},
	{#State 304
		DEFAULT => -178
	},
	{#State 305
		DEFAULT => -109
	},
	{#State 306
		ACTIONS => {
			'p_any' => 99,
			'p_name' => 21,
			'CLCURLY' => 318
		},
		GOTOS => {
			'perc_name' => 101,
			'perc_any_arg' => 142
		}
	},
	{#State 307
		DEFAULT => -180
	},
	{#State 308
		DEFAULT => -18
	},
	{#State 309
		ACTIONS => {
			'OPPAR' => 291
		}
	},
	{#State 310
		ACTIONS => {
			'CLPAR' => 319
		}
	},
	{#State 311
		ACTIONS => {
			'p_any' => 3
		},
		DEFAULT => -74,
		GOTOS => {
			'perc_any' => 321,
			'_member_metadata' => 320
		}
	},
	{#State 312
		ACTIONS => {
			'CLPAR' => 322
		}
	},
	{#State 313
		ACTIONS => {
			'INTEGER' => 323
		}
	},
	{#State 314
		ACTIONS => {
			'p_any' => 3,
			'p_alias' => 128,
			'p_code' => 131,
			'p_cleanup' => 125,
			'p_postcall' => 127,
			'p_catch' => 135
		},
		DEFAULT => -100,
		GOTOS => {
			'perc_postcall' => 130,
			'perc_code' => 124,
			'perc_any' => 132,
			'perc_cleanup' => 133,
			'perc_catch' => 126,
			'_function_metadata' => 134,
			'perc_alias' => 129
		}
	},
	{#State 315
		ACTIONS => {
			'CLCURLY' => 324
		}
	},
	{#State 316
		DEFAULT => -172
	},
	{#State 317
		ACTIONS => {
			'ID' => 28,
			'INTEGER' => 222,
			'QUOTED_STRING' => 224,
			'DASH' => 226,
			'FLOAT' => 225
		},
		GOTOS => {
			'class_name' => 220,
			'value' => 325
		}
	},
	{#State 318
		ACTIONS => {
			'SEMICOLON' => 326
		}
	},
	{#State 319
		DEFAULT => -95,
		GOTOS => {
			'function_metadata' => 327
		}
	},
	{#State 320
		DEFAULT => -68
	},
	{#State 321
		DEFAULT => -70
	},
	{#State 322
		DEFAULT => -95,
		GOTOS => {
			'function_metadata' => 328
		}
	},
	{#State 323
		DEFAULT => -95,
		GOTOS => {
			'function_metadata' => 329
		}
	},
	{#State 324
		DEFAULT => -24,
		GOTOS => {
			'mixed_blocks' => 330
		}
	},
	{#State 325
		DEFAULT => -174
	},
	{#State 326
		DEFAULT => -19
	},
	{#State 327
		ACTIONS => {
			'p_any' => 3,
			'p_alias' => 128,
			'p_code' => 131,
			'p_cleanup' => 125,
			'p_postcall' => 127,
			'p_catch' => 135
		},
		DEFAULT => -91,
		GOTOS => {
			'perc_postcall' => 130,
			'perc_code' => 124,
			'perc_any' => 132,
			'perc_cleanup' => 133,
			'perc_catch' => 126,
			'_function_metadata' => 134,
			'perc_alias' => 129
		}
	},
	{#State 328
		ACTIONS => {
			'p_any' => 3,
			'p_alias' => 128,
			'p_code' => 131,
			'p_cleanup' => 125,
			'p_postcall' => 127,
			'p_catch' => 135
		},
		DEFAULT => -89,
		GOTOS => {
			'perc_postcall' => 130,
			'perc_code' => 124,
			'perc_any' => 132,
			'perc_cleanup' => 133,
			'perc_catch' => 126,
			'_function_metadata' => 134,
			'perc_alias' => 129
		}
	},
	{#State 329
		ACTIONS => {
			'p_any' => 3,
			'p_alias' => 128,
			'p_code' => 131,
			'p_cleanup' => 125,
			'p_postcall' => 127,
			'p_catch' => 135
		},
		DEFAULT => -101,
		GOTOS => {
			'perc_postcall' => 130,
			'perc_code' => 124,
			'perc_any' => 132,
			'perc_cleanup' => 133,
			'perc_catch' => 126,
			'_function_metadata' => 134,
			'perc_alias' => 129
		}
	},
	{#State 330
		ACTIONS => {
			'OPCURLY' => 144,
			'OPSPECIAL' => 33,
			'SEMICOLON' => 331
		},
		GOTOS => {
			'simple_block' => 146,
			'special_block' => 145,
			'special_block_start' => 35
		}
	},
	{#State 331
		DEFAULT => -21
	}
],
                                  yyrules  =>
[
	[#Rule 0
		 '$start', 2, undef
	],
	[#Rule 1
		 'top_list', 1, undef
	],
	[#Rule 2
		 'top_list', 2,
sub
#line 22 "XSP.yp"
{ push @{$_[1]}, @{$_[2]}; $_[1] }
	],
	[#Rule 3
		 'top_list', 4,
sub
#line 24 "XSP.yp"
{ $_[3] }
	],
	[#Rule 4
		 'top', 1,
sub
#line 27 "XSP.yp"
{ !$_[1]               ? [] :
                          ref $_[1] eq 'ARRAY' ? $_[1] :
                                                 [ $_[1] ] }
	],
	[#Rule 5
		 '_top', 1, undef
	],
	[#Rule 6
		 '_top', 1, undef
	],
	[#Rule 7
		 '_top', 1, undef
	],
	[#Rule 8
		 '_top', 1, undef
	],
	[#Rule 9
		 '_top', 1,
sub
#line 32 "XSP.yp"
{ process_function( $_[0], $_[1] ) }
	],
	[#Rule 10
		 'directive', 2,
sub
#line 35 "XSP.yp"
{ ExtUtils::XSpp::Node::Module->new( module => $_[1] ) }
	],
	[#Rule 11
		 'directive', 2,
sub
#line 37 "XSP.yp"
{ ExtUtils::XSpp::Node::Package->new( perl_name => $_[1] ) }
	],
	[#Rule 12
		 'directive', 2,
sub
#line 39 "XSP.yp"
{ ExtUtils::XSpp::Node::File->new( file => $_[1] ) }
	],
	[#Rule 13
		 'directive', 2,
sub
#line 41 "XSP.yp"
{ $_[0]->YYData->{PARSER}->load_plugin( $_[1] ); undef }
	],
	[#Rule 14
		 'directive', 2,
sub
#line 43 "XSP.yp"
{ $_[0]->YYData->{PARSER}->include_file( $_[1] ); undef }
	],
	[#Rule 15
		 'directive', 2,
sub
#line 45 "XSP.yp"
{ add_top_level_directive( $_[0], %{$_[1][1]} ) }
	],
	[#Rule 16
		 'directive', 1,
sub
#line 46 "XSP.yp"
{ }
	],
	[#Rule 17
		 'directive', 1,
sub
#line 47 "XSP.yp"
{ }
	],
	[#Rule 18
		 'typemap', 9,
sub
#line 52 "XSP.yp"
{ my $c = 0;
                      my %args = map { "arg" . ++$c => $_ }
                                 map { join( '', @$_ ) }
                                     @{$_[8] || []};
                      add_typemap( $_[6], $_[3], %args );
                      undef }
	],
	[#Rule 19
		 'typemap', 11,
sub
#line 60 "XSP.yp"
{ # this assumes that there will be at most one named
                      # block for each directive inside the typemap
                      for( my $i = 1; $i <= $#{$_[9]}; $i += 2 ) {
                          $_[9][$i] = join "\n", @{$_[9][$i][0]}
                              if    ref( $_[9][$i] ) eq 'ARRAY'
                                 && ref( $_[9][$i][0] ) eq 'ARRAY';
                      }
                      add_typemap( $_[6], $_[3], @{$_[9]} );
                      undef }
	],
	[#Rule 20
		 'typemap', 5,
sub
#line 70 "XSP.yp"
{ add_typemap( 'simple', $_[3] );
                      add_typemap( 'reference', make_ref($_[3]->clone) );
                      undef }
	],
	[#Rule 21
		 'exceptionmap', 12,
sub
#line 78 "XSP.yp"
{ my $package = "ExtUtils::XSpp::Exception::" . $_[9];
                      my $type = make_type($_[6]); my $c = 0;
                      my %args = map { "arg" . ++$c => $_ }
                                 map { join( "\n", @$_ ) }
                                     @{$_[11] || []};
                      my $e = $package->new( name => $_[3], type => $type, %args );
                      ExtUtils::XSpp::Exception->add_exception( $e );
                      undef }
	],
	[#Rule 22
		 'mixed_blocks', 2,
sub
#line 88 "XSP.yp"
{ [ @{$_[1]}, $_[2] ] }
	],
	[#Rule 23
		 'mixed_blocks', 2,
sub
#line 90 "XSP.yp"
{ [ @{$_[1]}, [ $_[2] ] ] }
	],
	[#Rule 24
		 'mixed_blocks', 0,
sub
#line 91 "XSP.yp"
{ [] }
	],
	[#Rule 25
		 'simple_block', 3,
sub
#line 94 "XSP.yp"
{ $_[2] }
	],
	[#Rule 26
		 'raw', 1,
sub
#line 96 "XSP.yp"
{ add_data_raw( $_[0], [ $_[1] ] ) }
	],
	[#Rule 27
		 'raw', 1,
sub
#line 97 "XSP.yp"
{ add_data_comment( $_[0], $_[1] ) }
	],
	[#Rule 28
		 'raw', 1,
sub
#line 98 "XSP.yp"
{ ExtUtils::XSpp::Node::Preprocessor->new
                              ( rows   => [ $_[1][0] ],
                                symbol => $_[1][1],
                                ) }
	],
	[#Rule 29
		 'raw', 1,
sub
#line 102 "XSP.yp"
{ add_data_raw( $_[0], [ @{$_[1]} ] ) }
	],
	[#Rule 30
		 'enum', 5,
sub
#line 106 "XSP.yp"
{ ExtUtils::XSpp::Node::Enum->new
                ( elements  => $_[3],
                  condition => $_[0]->get_conditional,
                  ) }
	],
	[#Rule 31
		 'enum', 6,
sub
#line 111 "XSP.yp"
{ ExtUtils::XSpp::Node::Enum->new
                ( name      => $_[2],
                  elements  => $_[4],
                  condition => $_[0]->get_conditional,
                  ) }
	],
	[#Rule 32
		 'enum_element_list', 0,
sub
#line 119 "XSP.yp"
{ [] }
	],
	[#Rule 33
		 'enum_element_list', 2,
sub
#line 121 "XSP.yp"
{ push @{$_[1]}, $_[2] if $_[2]; $_[1] }
	],
	[#Rule 34
		 'enum_element_list', 3,
sub
#line 123 "XSP.yp"
{ push @{$_[1]}, $_[2] if $_[2]; $_[1] }
	],
	[#Rule 35
		 'enum_element', 1,
sub
#line 128 "XSP.yp"
{ ExtUtils::XSpp::Node::EnumValue->new
                ( name => $_[1],
                  condition => $_[0]->get_conditional,
                  ) }
	],
	[#Rule 36
		 'enum_element', 3,
sub
#line 133 "XSP.yp"
{ ExtUtils::XSpp::Node::EnumValue->new
                ( name      => $_[1],
                  value     => $_[3],
                  condition => $_[0]->get_conditional,
                  ) }
	],
	[#Rule 37
		 'enum_element', 1, undef
	],
	[#Rule 38
		 'class', 2, undef
	],
	[#Rule 39
		 'class', 2, undef
	],
	[#Rule 40
		 'function', 2, undef
	],
	[#Rule 41
		 'method', 2, undef
	],
	[#Rule 42
		 'member', 2, undef
	],
	[#Rule 43
		 'decorate_class', 2,
sub
#line 147 "XSP.yp"
{ $_[2]->set_perl_name( $_[1] ); $_[2] }
	],
	[#Rule 44
		 'class_decl', 7,
sub
#line 150 "XSP.yp"
{ create_class( $_[0], $_[2], $_[3], $_[4], $_[6],
                                $_[0]->get_conditional ) }
	],
	[#Rule 45
		 'base_classes', 2,
sub
#line 154 "XSP.yp"
{ [ $_[2] ] }
	],
	[#Rule 46
		 'base_classes', 3,
sub
#line 155 "XSP.yp"
{ push @{$_[1]}, $_[3] if $_[3]; $_[1] }
	],
	[#Rule 47
		 'base_classes', 0, undef
	],
	[#Rule 48
		 'base_class', 2,
sub
#line 159 "XSP.yp"
{ $_[2] }
	],
	[#Rule 49
		 'base_class', 2,
sub
#line 160 "XSP.yp"
{ $_[2] }
	],
	[#Rule 50
		 'base_class', 2,
sub
#line 161 "XSP.yp"
{ $_[2] }
	],
	[#Rule 51
		 'class_name_rename', 1,
sub
#line 165 "XSP.yp"
{ create_class( $_[0], $_[1], [], [] ) }
	],
	[#Rule 52
		 'class_name_rename', 2,
sub
#line 166 "XSP.yp"
{ my $klass = create_class( $_[0], $_[2], [], [] );
                             $klass->set_perl_name( $_[1] );
                             $klass
                             }
	],
	[#Rule 53
		 'class_metadata', 2,
sub
#line 172 "XSP.yp"
{ [ @{$_[1]}, @{$_[2]} ] }
	],
	[#Rule 54
		 'class_metadata', 2,
sub
#line 173 "XSP.yp"
{ [ @{$_[1]}, @{$_[2]} ] }
	],
	[#Rule 55
		 'class_metadata', 0,
sub
#line 174 "XSP.yp"
{ [] }
	],
	[#Rule 56
		 'class_body_list', 0,
sub
#line 178 "XSP.yp"
{ [] }
	],
	[#Rule 57
		 'class_body_list', 2,
sub
#line 180 "XSP.yp"
{ push @{$_[1]}, $_[2] if $_[2]; $_[1] }
	],
	[#Rule 58
		 'class_body_element', 1, undef
	],
	[#Rule 59
		 'class_body_element', 1, undef
	],
	[#Rule 60
		 'class_body_element', 1, undef
	],
	[#Rule 61
		 'class_body_element', 1, undef
	],
	[#Rule 62
		 'class_body_element', 1, undef
	],
	[#Rule 63
		 'class_body_element', 1, undef
	],
	[#Rule 64
		 'class_body_element', 2,
sub
#line 186 "XSP.yp"
{ ExtUtils::XSpp::Node::PercAny->new( %{$_[1][1]} ) }
	],
	[#Rule 65
		 'access_specifier', 2,
sub
#line 190 "XSP.yp"
{ ExtUtils::XSpp::Node::Access->new( access => $_[1] ) }
	],
	[#Rule 66
		 'access_specifier', 2,
sub
#line 191 "XSP.yp"
{ ExtUtils::XSpp::Node::Access->new( access => $_[1] ) }
	],
	[#Rule 67
		 'access_specifier', 2,
sub
#line 192 "XSP.yp"
{ ExtUtils::XSpp::Node::Access->new( access => $_[1] ) }
	],
	[#Rule 68
		 'member_metadata', 2,
sub
#line 195 "XSP.yp"
{ [ @{$_[1]}, @{$_[2]} ] }
	],
	[#Rule 69
		 'member_metadata', 0,
sub
#line 196 "XSP.yp"
{ [] }
	],
	[#Rule 70
		 '_member_metadata', 1, undef
	],
	[#Rule 71
		 'member_decl', 0, undef
	],
	[#Rule 72
		 'member_decl', 1, undef
	],
	[#Rule 73
		 'member_decl', 2,
sub
#line 204 "XSP.yp"
{ $_[2]->set_perl_name( $_[1] ); $_[2] }
	],
	[#Rule 74
		 'looks_like_member', 3,
sub
#line 208 "XSP.yp"
{ create_member( $_[0],
                           name      => $_[2],
                           type      => $_[1],
                           condition => $_[0]->get_conditional,
                           @{$_[3]} ) }
	],
	[#Rule 75
		 'method_decl', 1, undef
	],
	[#Rule 76
		 'method_decl', 1, undef
	],
	[#Rule 77
		 'method_decl', 1, undef
	],
	[#Rule 78
		 'method_decl', 1, undef
	],
	[#Rule 79
		 'const', 1,
sub
#line 216 "XSP.yp"
{ 1 }
	],
	[#Rule 80
		 'const', 0,
sub
#line 217 "XSP.yp"
{ 0 }
	],
	[#Rule 81
		 'virtual', 1, undef
	],
	[#Rule 82
		 'static', 1, undef
	],
	[#Rule 83
		 'static', 1, undef
	],
	[#Rule 84
		 'static', 1,
sub
#line 223 "XSP.yp"
{ 'package_static' }
	],
	[#Rule 85
		 'looks_like_function', 6,
sub
#line 228 "XSP.yp"
{
              return { ret_type  => $_[1],
                       name      => $_[2],
                       arguments => $_[4],
                       const     => $_[6],
                       };
          }
	],
	[#Rule 86
		 'looks_like_renamed_function', 1, undef
	],
	[#Rule 87
		 'looks_like_renamed_function', 2,
sub
#line 239 "XSP.yp"
{ $_[2]->{perl_name} = $_[1]; $_[2] }
	],
	[#Rule 88
		 'function_decl', 2,
sub
#line 242 "XSP.yp"
{ add_data_function( $_[0],
                                         name      => $_[1]->{name},
                                         perl_name => $_[1]->{perl_name},
                                         ret_type  => $_[1]->{ret_type},
                                         arguments => $_[1]->{arguments},
                                         condition => $_[0]->get_conditional,
                                         @{$_[2]} ) }
	],
	[#Rule 89
		 'ctor', 5,
sub
#line 251 "XSP.yp"
{ add_data_ctor( $_[0], name      => $_[1],
                                            arguments => $_[3],
                                            condition => $_[0]->get_conditional,
                                            @{ $_[5] } ) }
	],
	[#Rule 90
		 'ctor', 2,
sub
#line 255 "XSP.yp"
{ $_[2]->set_perl_name( $_[1] ); $_[2] }
	],
	[#Rule 91
		 'dtor', 5,
sub
#line 258 "XSP.yp"
{ add_data_dtor( $_[0], name  => $_[2],
                                            condition => $_[0]->get_conditional,
                                            @{ $_[5] },
                                      ) }
	],
	[#Rule 92
		 'dtor', 2,
sub
#line 262 "XSP.yp"
{ $_[2]->set_perl_name( $_[1] ); $_[2] }
	],
	[#Rule 93
		 'dtor', 2,
sub
#line 263 "XSP.yp"
{ $_[2]->set_virtual( 1 ); $_[2] }
	],
	[#Rule 94
		 'function_metadata', 2,
sub
#line 265 "XSP.yp"
{ [ @{$_[1]}, @{$_[2]} ] }
	],
	[#Rule 95
		 'function_metadata', 0,
sub
#line 266 "XSP.yp"
{ [] }
	],
	[#Rule 96
		 'nmethod', 2,
sub
#line 271 "XSP.yp"
{ my $m = add_data_method
                        ( $_[0],
                          name      => $_[1]->{name},
                          perl_name => $_[1]->{perl_name},
                          ret_type  => $_[1]->{ret_type},
                          arguments => $_[1]->{arguments},
                          const     => $_[1]->{const},
                          condition => $_[0]->get_conditional,
                          @{$_[2]},
                          );
            $m
          }
	],
	[#Rule 97
		 'nmethod', 2,
sub
#line 284 "XSP.yp"
{ $_[2]->set_static( $_[1] ); $_[2] }
	],
	[#Rule 98
		 'vmethod', 1, undef
	],
	[#Rule 99
		 'vmethod', 2,
sub
#line 289 "XSP.yp"
{ $_[2]->set_perl_name( $_[1] ); $_[2] }
	],
	[#Rule 100
		 '_vmethod', 3,
sub
#line 294 "XSP.yp"
{ my $m = add_data_method
                        ( $_[0],
                          name      => $_[2]->{name},
                          perl_name => $_[2]->{perl_name},
                          ret_type  => $_[2]->{ret_type},
                          arguments => $_[2]->{arguments},
                          const     => $_[2]->{const},
                          condition => $_[0]->get_conditional,
                          @{$_[3]},
                          );
            $m->set_virtual( 1 );
            $m
          }
	],
	[#Rule 101
		 '_vmethod', 5,
sub
#line 308 "XSP.yp"
{ my $m = add_data_method
                        ( $_[0],
                          name      => $_[2]->{name},
                          perl_name => $_[2]->{perl_name},
                          ret_type  => $_[2]->{ret_type},
                          arguments => $_[2]->{arguments},
                          const     => $_[2]->{const},
                          condition => $_[0]->get_conditional,
                          @{$_[5]},
                          );
            die "Invalid pure virtual method" unless $_[4] eq '0';
            $m->set_virtual( 2 );
            $m
          }
	],
	[#Rule 102
		 '_function_metadata', 1, undef
	],
	[#Rule 103
		 '_function_metadata', 1, undef
	],
	[#Rule 104
		 '_function_metadata', 1, undef
	],
	[#Rule 105
		 '_function_metadata', 1, undef
	],
	[#Rule 106
		 '_function_metadata', 1, undef
	],
	[#Rule 107
		 '_function_metadata', 1, undef
	],
	[#Rule 108
		 'perc_name', 4,
sub
#line 332 "XSP.yp"
{ $_[3] }
	],
	[#Rule 109
		 'perc_alias', 6,
sub
#line 333 "XSP.yp"
{ [ alias => [$_[3], $_[5]] ] }
	],
	[#Rule 110
		 'perc_package', 4,
sub
#line 334 "XSP.yp"
{ $_[3] }
	],
	[#Rule 111
		 'perc_module', 4,
sub
#line 335 "XSP.yp"
{ $_[3] }
	],
	[#Rule 112
		 'perc_file', 4,
sub
#line 336 "XSP.yp"
{ $_[3] }
	],
	[#Rule 113
		 'perc_loadplugin', 4,
sub
#line 337 "XSP.yp"
{ $_[3] }
	],
	[#Rule 114
		 'perc_include', 4,
sub
#line 338 "XSP.yp"
{ $_[3] }
	],
	[#Rule 115
		 'perc_code', 2,
sub
#line 339 "XSP.yp"
{ [ code => $_[2] ] }
	],
	[#Rule 116
		 'perc_cleanup', 2,
sub
#line 340 "XSP.yp"
{ [ cleanup => $_[2] ] }
	],
	[#Rule 117
		 'perc_postcall', 2,
sub
#line 341 "XSP.yp"
{ [ postcall => $_[2] ] }
	],
	[#Rule 118
		 'perc_catch', 4,
sub
#line 342 "XSP.yp"
{ [ map {(catch => $_)} @{$_[3]} ] }
	],
	[#Rule 119
		 'perc_any', 4,
sub
#line 347 "XSP.yp"
{ [ tag => { any => $_[1], named => $_[3] } ] }
	],
	[#Rule 120
		 'perc_any', 5,
sub
#line 349 "XSP.yp"
{ [ tag => { any => $_[1], positional  => [ $_[3], @{$_[5]} ] } ] }
	],
	[#Rule 121
		 'perc_any', 3,
sub
#line 351 "XSP.yp"
{ [ tag => { any => $_[1], positional  => [ $_[2], @{$_[3]} ] } ] }
	],
	[#Rule 122
		 'perc_any', 1,
sub
#line 353 "XSP.yp"
{ [ tag => { any => $_[1] } ] }
	],
	[#Rule 123
		 'perc_any_args', 1,
sub
#line 357 "XSP.yp"
{ $_[1] }
	],
	[#Rule 124
		 'perc_any_args', 2,
sub
#line 358 "XSP.yp"
{ [ @{$_[1]}, @{$_[2]} ] }
	],
	[#Rule 125
		 'perc_any_arg', 3,
sub
#line 362 "XSP.yp"
{ [ $_[1] => $_[2] ] }
	],
	[#Rule 126
		 'perc_any_arg', 2,
sub
#line 363 "XSP.yp"
{ [ name  => $_[1] ] }
	],
	[#Rule 127
		 'type', 2,
sub
#line 367 "XSP.yp"
{ make_const( $_[2] ) }
	],
	[#Rule 128
		 'type', 1, undef
	],
	[#Rule 129
		 'nconsttype', 2,
sub
#line 372 "XSP.yp"
{ make_ptr( $_[1] ) }
	],
	[#Rule 130
		 'nconsttype', 2,
sub
#line 373 "XSP.yp"
{ make_ref( $_[1] ) }
	],
	[#Rule 131
		 'nconsttype', 1,
sub
#line 374 "XSP.yp"
{ make_type( $_[1] ) }
	],
	[#Rule 132
		 'nconsttype', 1, undef
	],
	[#Rule 133
		 'type_name', 1, undef
	],
	[#Rule 134
		 'type_name', 1, undef
	],
	[#Rule 135
		 'type_name', 1, undef
	],
	[#Rule 136
		 'type_name', 1,
sub
#line 382 "XSP.yp"
{ 'unsigned int' }
	],
	[#Rule 137
		 'type_name', 2,
sub
#line 383 "XSP.yp"
{ 'unsigned' . ' ' . $_[2] }
	],
	[#Rule 138
		 'basic_type', 1, undef
	],
	[#Rule 139
		 'basic_type', 1, undef
	],
	[#Rule 140
		 'basic_type', 1, undef
	],
	[#Rule 141
		 'basic_type', 1, undef
	],
	[#Rule 142
		 'basic_type', 2, undef
	],
	[#Rule 143
		 'basic_type', 2, undef
	],
	[#Rule 144
		 'template', 4,
sub
#line 389 "XSP.yp"
{ make_template( $_[1], $_[3] ) }
	],
	[#Rule 145
		 'type_list', 1,
sub
#line 393 "XSP.yp"
{ [ $_[1] ] }
	],
	[#Rule 146
		 'type_list', 3,
sub
#line 394 "XSP.yp"
{ push @{$_[1]}, $_[3]; $_[1] }
	],
	[#Rule 147
		 'class_name', 1, undef
	],
	[#Rule 148
		 'class_name', 2,
sub
#line 398 "XSP.yp"
{ $_[1] . '::' . $_[2] }
	],
	[#Rule 149
		 'class_name_list', 1,
sub
#line 401 "XSP.yp"
{ [ $_[1] ] }
	],
	[#Rule 150
		 'class_name_list', 3,
sub
#line 402 "XSP.yp"
{ push @{$_[1]}, $_[3]; $_[1] }
	],
	[#Rule 151
		 'class_suffix', 2,
sub
#line 405 "XSP.yp"
{ $_[2] }
	],
	[#Rule 152
		 'class_suffix', 3,
sub
#line 406 "XSP.yp"
{ $_[1] . '::' . $_[3] }
	],
	[#Rule 153
		 'file_name', 1,
sub
#line 408 "XSP.yp"
{ '-' }
	],
	[#Rule 154
		 'file_name', 3,
sub
#line 409 "XSP.yp"
{ $_[1] . '.' . $_[3] }
	],
	[#Rule 155
		 'file_name', 3,
sub
#line 410 "XSP.yp"
{ $_[1] . '/' . $_[3] }
	],
	[#Rule 156
		 'arg_list', 1, undef
	],
	[#Rule 157
		 'arg_list', 1,
sub
#line 413 "XSP.yp"
{ undef }
	],
	[#Rule 158
		 'nonvoid_arg_list', 1,
sub
#line 416 "XSP.yp"
{ [ $_[1] ] }
	],
	[#Rule 159
		 'nonvoid_arg_list', 3,
sub
#line 417 "XSP.yp"
{ push @{$_[1]}, $_[3]; $_[1] }
	],
	[#Rule 160
		 'nonvoid_arg_list', 0, undef
	],
	[#Rule 161
		 'argument_metadata', 2,
sub
#line 420 "XSP.yp"
{ [ @{$_[1]}, @{$_[2]} ] }
	],
	[#Rule 162
		 'argument_metadata', 0,
sub
#line 421 "XSP.yp"
{ [] }
	],
	[#Rule 163
		 '_argument_metadata', 1, undef
	],
	[#Rule 164
		 'argument', 5,
sub
#line 427 "XSP.yp"
{ make_argument( @_[0, 1], "length($_[4])" ) }
	],
	[#Rule 165
		 'argument', 5,
sub
#line 429 "XSP.yp"
{ make_argument( @_[0, 1, 2, 5], @{$_[3]} ) }
	],
	[#Rule 166
		 'argument', 3,
sub
#line 431 "XSP.yp"
{ make_argument( @_[0, 1, 2], undef, @{$_[3]} ) }
	],
	[#Rule 167
		 'value', 1, undef
	],
	[#Rule 168
		 'value', 2,
sub
#line 434 "XSP.yp"
{ '-' . $_[2] }
	],
	[#Rule 169
		 'value', 1, undef
	],
	[#Rule 170
		 'value', 1, undef
	],
	[#Rule 171
		 'value', 1, undef
	],
	[#Rule 172
		 'value', 4,
sub
#line 438 "XSP.yp"
{ "$_[1]($_[3])" }
	],
	[#Rule 173
		 'value_list', 1, undef
	],
	[#Rule 174
		 'value_list', 3,
sub
#line 443 "XSP.yp"
{ "$_[1], $_[2]" }
	],
	[#Rule 175
		 'value_list', 0,
sub
#line 444 "XSP.yp"
{ "" }
	],
	[#Rule 176
		 'expression', 1, undef
	],
	[#Rule 177
		 'expression', 3,
sub
#line 450 "XSP.yp"
{ "$_[1] & $_[3]" }
	],
	[#Rule 178
		 'expression', 3,
sub
#line 452 "XSP.yp"
{ "$_[1] | $_[3]" }
	],
	[#Rule 179
		 'special_blocks', 1,
sub
#line 456 "XSP.yp"
{ [ $_[1] ] }
	],
	[#Rule 180
		 'special_blocks', 2,
sub
#line 458 "XSP.yp"
{ [ @{$_[1]}, $_[2] ] }
	],
	[#Rule 181
		 'special_blocks', 0, undef
	],
	[#Rule 182
		 'special_block', 3,
sub
#line 462 "XSP.yp"
{ $_[2] }
	],
	[#Rule 183
		 'special_block', 2,
sub
#line 464 "XSP.yp"
{ [] }
	],
	[#Rule 184
		 'special_block_start', 1,
sub
#line 467 "XSP.yp"
{ push_lex_mode( $_[0], 'special' ) }
	],
	[#Rule 185
		 'special_block_end', 1,
sub
#line 469 "XSP.yp"
{ pop_lex_mode( $_[0], 'special' ) }
	],
	[#Rule 186
		 'lines', 1,
sub
#line 471 "XSP.yp"
{ [ $_[1] ] }
	],
	[#Rule 187
		 'lines', 2,
sub
#line 472 "XSP.yp"
{ push @{$_[1]}, $_[2]; $_[1] }
	]
],
                                  @_);
    bless($self,$class);
}

#line 474 "XSP.yp"


use ExtUtils::XSpp::Lexer;

1;
