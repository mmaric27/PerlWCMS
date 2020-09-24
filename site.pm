############################################################################
# Module    : site.pm
# Created by: Marko Maric
# Created   : 2002-05-15
# Modified  : 2005-04-09
############################################################################
package NAS4::site;

    use strict;
    use CGI qw/:standard/;
    use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
    use DBI;


############################################################################
#   BEGIN - FUNCTION new
#       creates new site object
#   Created   : 2004-12-21
#   Modified  : 2004-12-21
############################################################################
sub new {                                                                   # @METAGS new
    my($class) = @_;

    my $self = {};
    bless $self, $class;

    $self->{'q'           } = new CGI;
    $self->{'params'      } = {$self->{'q'}->Vars};
    $self->{'config'      } = {$self->read_cnf()};
    $self->{'dbh'         } = {$self->connect()};
    $self->{'script'      } = substr(substr($ENV{'SCRIPT_NAME'},0,rindex($ENV{'SCRIPT_NAME'},'.')),rindex(substr($ENV{'SCRIPT_NAME'},0,rindex($ENV{'SCRIPT_NAME'},'.')),'/')+1);
    $self->{'subst_values'} = {(
                                %{$self->{'config'}},
                                %{$self->{'params'}},
                                script => $self->{'script'}
                              )};

    $self->{'config'      }{'langs_code'} = ($self->select_any('select code _code from languages where languages.id='.$self->{'params'}{'langs_id'}))[0]->{'code'};

#    if ( $self->file($Pconfig{'SCREEN_CSSFILE'},$Pconfig{'CSSEXT'},$Pconfig{'CSSDIR'},'e') ) {
#        open(SCREEN_CSS,"< ".$self->file($Pconfig{'SCREEN_CSSFILE'},$Pconfig{'CSSEXT'},$Pconfig{'CSSDIR'})) || die 'Error opening css file '.$self->file($Pconfig{'SCREEN_CSSFILE'},$Pconfig{'CSSEXT'},$Pconfig{'CSSDIR'});
#        while ( my $Tline = <SCREEN_CSS> ) {
#            if ( $Tline =~ /\.(.*)\s{/ ) { $Pconfig{'screen_css_styles'} .= ','."\n".'"'.$1.'" : "'.$1.'"'; }
#        }
#        close(SCREEN_CSS);
#    }
#    if ( $self->file($Pconfig{'PRINT_CSSFILE'},$Pconfig{'CSSEXT'},$Pconfig{'CSSDIR'},'e') ) {
#        open(PRINT_CSS,"< ".$self->file($Pconfig{'PRINT_CSSFILE'},$Pconfig{'CSSEXT'},$Pconfig{'CSSDIR'})) || die 'Error opening css file '.$self->file($Pconfig{'PRINT_CSSFILE'},$Pconfig{'CSSEXT'},$Pconfig{'CSSDIR'});
#        while ( my $Tline = <PRINT_CSS> ) {
#            if ( $Tline =~ /\.(.*)\s{/ ) { $Pconfig{'print_css_styles'} .= ','."\n".'"'.$1.'" : "'.$1.'"'; }
#        }
#        close(PRINT_CSS);
#    }

    return $self;
}
############################################################################
#   END - FUNCTION new
############################################################################


############################################################################
#   BEGIN - FUNCTION read_cnf
#       reads configuration file
#   Created   : 2004-11-16
#   Modified  : 2004-12-21
############################################################################
sub read_cnf {                                                              # @METAGS read_cnf
    my $self    = $_[0];
    my $Pname   = defined $_[1] ?   $_[1]  : 'main.cnf';
    my $Pext    = defined $_[2] ?   $_[2]  :         '';
    my $Ppath   = defined $_[3] ?   $_[3]  :         '';
    my %Pconfig = defined $_[4] ? %{$_[4]} :         ();

    if ( $self->file($Pname,$Pext,$Ppath,'e') ) {
        my $Ttext = '';
        open(CNF_FILE,"< ".$self->file($Pname,$Pext,$Ppath)) || $self->error("Error opening config file ".$self->file($Pname,$Pext,$Ppath));
        while ( my $Tline = <CNF_FILE> ) {
            if ( $Tline !~ /^#/ ) {
                $Ttext .= $Tline;
                if ( ($Ttext =~ /([\w\W]+)\n+([\w\W]+=>[\w\W]+)+\n?$/) ) {
                    my $Tconfig = $1;
                    $Ttext = $2;
                    $Tconfig =~ s/([\w\W]?)\n*$/$1/;
                    $Tconfig =~ s/([\w\W]?)\s*\/\/[\w\W]*/$1/;
                    %Pconfig = $self->parse_cnf(\%Pconfig,$Tconfig);
                }
            }
        }
        close(CNF_FILE);
        %Pconfig = $self->parse_cnf(\%Pconfig,$Ttext);
    }

    foreach my $Tconfig ( keys %Pconfig ) {
        $Pconfig{$Tconfig} = $self->subst_vars($self->subst_vars($Pconfig{$Tconfig}, \%Pconfig), \%{$self->{'params'}});
    }

    return %Pconfig;
}
############################################################################
#   END - FUNCTION read_cnf
############################################################################


############################################################################
#   BEGIN - FUNCTION parse_cnf
#       parses configuration text
#   Created   : 2004-12-15
#   Modified  : 2004-12-21
############################################################################
sub parse_cnf {                                                             # @METAGS parse_cnf
    my $self = $_[0];
    my %Pconfig = defined $_[1] ? %{$_[1]} : ();
    my $Ptext   = defined $_[2] ?   $_[2]  : '';
    my ($Tvar_name, $Tvar_value) = split /\s*=>\s*/,$Ptext;
    if ( defined $Tvar_name && defined $Tvar_value ) {
        $Tvar_name  =~ s/^\s*(\w*)\s*$/$1/;
        $Tvar_value =~ s/^\s*(\w*)\s*$/$1/;
        if ( $Tvar_name ne 'params' ) {
                $Pconfig{$Tvar_name} = ($Tvar_name =~ /start/)||($Tvar_name =~ /end/) ? lc($Tvar_value) : $Tvar_value;
        } else {
            if ( defined $self->{'params'} ) {
                foreach my $Tparam ( split /,/,$Tvar_value ) {
                    my ($Tname, $Tvalue) = split /\#/,$Tparam;
                    if ( !defined $self->{'params'}{$Tname} ) { $self->{'params'}{$Tname} = $Tvalue; }
                }
            }
        }
    }
    return %Pconfig;
}
############################################################################
#   END - FUNCTION parse_cnf
############################################################################


############################################################################
#   BEGIN - FUNCTION lc
#       to lowercase
#   input params:
#       0: value to replace
#   output params:
#       0: replaced value
#   Created : 2003-01-18
#   Modified: 2004-12-21
############################################################################
sub lc {                                                                    # @METAGS lc
    my $self = $_[0];
    my $Tresult = defined $_[1] ? lc($_[1]) : '';
    if ( $Tresult ne '' ) {
      $Tresult =~ s/©/¹/g;
      $Tresult =~ s/Ð/ð/g;
      $Tresult =~ s/È/è/g;
      $Tresult =~ s/Æ/æ/g;
      $Tresult =~ s/®/¾/g;
    }
    return $Tresult;
}
############################################################################
#   END - FUNCTION lc
############################################################################


############################################################################
#   BEGIN - FUNCTION uc
#       to uppercase
#   input params:
#       0: value to replace
#   output params:
#       0: replaced value
#   Created : 2003-01-18
#   Modified: 2003-01-18
############################################################################
sub uc {                                                                    # @METAGS uc
    my $self = $_[0];
    my $Tresult = defined $_[1] ? uc($_[1]) : '';
    if ( $Tresult ne '' ) {
      $Tresult =~ s/¹/©/g;
      $Tresult =~ s/ð/Ð/g;
      $Tresult =~ s/è/È/g;
      $Tresult =~ s/æ/Æ/g;
      $Tresult =~ s/¾/®/g;
    }
    return $Tresult;
}
############################################################################
#   END - FUNCTION uc
############################################################################


############################################################################
#   BEGIN - FUNCTION connect
#       connects to database
#   input params:
#       0: hash of database handles
#       1: database tag
#   ouput params:
#       0: hash of database handles
#   Created : 2002-05-20
#   Modified: 2004-12-21
############################################################################
sub connect {                                                               # @METAGS connect
    my $self = $_[0];
    my $Ptag = defined $_[1] ?   $_[1]  : (defined $self->{'config'}{'main_db'} ? $self->{'config'}{'main_db'} : '');
    my %Pdbh = defined $_[2] ? %{$_[2]} :                           ();

    if ( defined $self->{'config'}{$Ptag.'_db_name'    } ) {
        if ( !defined $self->{'config'}{$Ptag.'_db_server'  } ) { $self->{'config'}{$Ptag.'_db_server'  } = 'localhost'   ; }
        if ( !defined $self->{'config'}{$Ptag.'_db_username'} ) { $self->error('Database username parameter missing'         ); }
        if ( !defined $self->{'config'}{$Ptag.'_db_password'} ) { $self->error('Database password parameter missing'         ); }

        my $Tbaza = 'DBI:mysql:'.$self->{'config'}{$Ptag.'_db_name'}.':'.$self->{'config'}{$Ptag.'_db_server'};
        my $Tuser = $self->{'config'}{$Ptag.'_db_username'};
        my $Tpass = $self->{'config'}{$Ptag.'_db_password'};
        $Pdbh{$Ptag} = DBI->connect($Tbaza, $Tuser, $Tpass)  || die DBI::errstr;
    }
    return %Pdbh;
}
############################################################################
#   END - FUNCTION connect
############################################################################


############################################################################
#   BEGIN - FUNCTION disconnect
#       disconnects from database
#   input params:
#       0: database handle
#   Created : 2002-05-20
#   Modified: 2004-12-21
############################################################################
sub disconnect {                                                            # @METAGS disconnect
    my $self = $_[0];
    my %Pdbh = defined $_[1] ? %{$_[1]} : ();
    my $Ptag = defined $_[2] ?   $_[2]  : '';

    if ( $Ptag ne '' ) {
        if ( defined $Pdbh{$Ptag} ) { $Pdbh{$Ptag}->disconnect || die $Pdbh{$Ptag}->errstr(); }
    } else {
        foreach my $Ttag ( keys %Pdbh ) {
            if ( defined $Pdbh{$Ttag} ) { $Pdbh{$Ttag}->disconnect || die $Pdbh{$Ttag}->errstr(); }
        }
    }
}
############################################################################
#   END - FUNCTION disconnect
############################################################################


############################################################################
#   BEGIN - FUNCTION tpl_header
#       generates top portion of web site
#   Created   : 2003-04-04
#   Modified  : 2004-12-21
############################################################################
sub tpl_header {                                                            # @METAGS tpl_header
    print header( -charset=>'iso-8859-2' );
    warningsToBrowser(1);
}
############################################################################
#   END - FUNCTION tpl_header
############################################################################


############################################################################
#   BEGIN - FUNCTION free
#       closes database connection, and frees common
#   Created   : 2003-04-04
#   Modified  : 2004-12-21
############################################################################
sub free {                                                                  # @METAGS free
    my $self = $_[0];

    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
    $self->disconnect(\%{$self->{'dbh'}});
    undef $self;
}
############################################################################
#   END - FUNCTION free
############################################################################


############################################################################
#   BEGIN - FUNCTION form_site
#   Created   : 2003-05-31
#   Modified  : 2004-12-21
############################################################################
sub form_site {                                                             # @METAGS form_site
    my $self = $_[0];
    my $Ttag = defined $self->{'q'}->param('tag') ? $self->{'q'}->param('tag') : $self->{'config'}{'index_tag'};
    $self->form_tag($Ttag);
}
############################################################################
#   END - FUNCTION form_site
############################################################################


############################################################################
#   BEGIN - FUNCTION form_tag
#   input params:
#       0: tag to render
#       1: values to replace inside sql
#       2: values to replace inside tpl
#       3: safety recursion level
#   Created   : 2003-05-31
#   Modified  : 2004-12-21
############################################################################
sub form_tag {                                                              # @METAGS form_tag
    my $self = $_[0];
    my $Ptag         = defined $_[1] ?   $_[1]  : '';
    my %Psql_values  = defined $_[2] ? %{$_[2]} : ();
    my %Pvars_values = defined $_[3] ? %{$_[3]} : ();
    my $Plevel       = defined $_[4] ?   $_[4]  :  0;
    $Ptag = $self->subst_vars($Ptag,\%{$self->{'subst_values'}});
    if ( $Plevel >= $self->{'config'}{'max_level'} ) { $self->free; exit 0; }

    my $Ttext = '';
    my $Tsql  = '';
    if ( $self->file($Ptag,$self->{'config'}{'TPLEXT'},$self->{'config'}{'TPLDIR'},'e') ) {
        open(TPL,"< ".$self->file($Ptag,$self->{'config'}{'TPLEXT'},$self->{'config'}{'TPLDIR'})) || die 'Error opening tpl file '.$self->file($Ptag,$self->{'config'}{'TPLEXT'},$self->{'config'}{'TPLDIR'});
        while ( my $Tline = <TPL> ) { $Ttext .= $Tline; }
        close(TPL);
        my %Ttext_langs = $self->read_cnf($Ptag,'.'.$self->{'config'}{'langs_code'},$self->{'config'}{'LNGDIR'});
        $Ttext = $self->subst_langs($Ttext,\%Ttext_langs);
        $Ttext =~ s/\n$//gm;
        if ( $self->file($Ptag,$self->{'config'}{'SQLEXT'},$self->{'config'}{'SQLDIR'},'e') ) {
            open(SQL,"< ".$self->file($Ptag,$self->{'config'}{'SQLEXT'},$self->{'config'}{'SQLDIR'})) || die 'Error opening sql file '.$self->file($Ptag,$self->{'config'}{'SQLEXT'},$self->{'config'}{'SQLDIR'});
            while ( my $Tline = <SQL> ) { $Tsql .= $Tline; }
            close(SQL);
        }
    }
    if ( ($Ttext eq '') || ($Tsql eq '') ) {
        my %Tvalues = (tag => $Ptag);
        my @Ttag = defined $self->{'config'}{'sql_tag_site'} ? $self->rtrim($self->{'config'}{'sql_tag_site'} ne '') ? $self->select_any($self->{'config'}{'sql_tag_site'}, \%Tvalues) : () : ();
        if ($Ttext eq '') { $Ttext = defined $Ttag[0]->{'text'} ? $Ttag[0]->{'text'} : ''; }
        if ($Tsql  eq '') { $Tsql  = defined $Ttag[0]->{'sql' } ? $Ttag[0]->{'sql' } : ''; }
    }
    if ($Ttext eq '') { $Ttext = defined $self->{'config'}{'tpl_tag_'.$Ptag} ? $self->{'config'}{'tpl_tag_'.$Ptag} : ''; }
    if ($Tsql  eq '') { $Tsql  = defined $self->{'config'}{'sql_tag_'.$Ptag} ? $self->{'config'}{'sql_tag_'.$Ptag} : ''; }

    if ( $Tsql eq '' ) {
        $self->form_tpl($Ttext,\%Psql_values,\%Pvars_values,$Plevel);
    } else {
        my @Tsql = $self->select_any($Tsql,\%Psql_values);
        for my $i ( 0 .. $#Tsql ) {
            my %Tvalues = ();
            foreach my $Tfield ( keys %{$Tsql[$i]} ) {
                $Tvalues{$Tfield} = $Tsql[$i]->{$Tfield};
            }
            $self->form_tpl($self->subst_vars($Ttext, \%Tvalues),\%Psql_values,\%Pvars_values,$Plevel);
        }
        %Psql_values = ();
    }
}
############################################################################
#   END - FUNCTION form_tag
############################################################################


############################################################################
#   BEGIN - FUNCTION form_tpl
#   input params:
#       0: text
#       1: sql values
#       2: vars values
#       3: level
#   Created   : 2003-05-31
#   Modified  : 2004-12-12
############################################################################
sub form_tpl {                                                              # @METAGS form_tpl
    my $self = $_[0];
    my $Ptext        = defined $_[1] ?   $_[1]  : '';
    my %Psql_values  = defined $_[2] ? %{$_[2]} : ();
    my %Pvars_values = defined $_[3] ? %{$_[3]} : ();
    my $Plevel       = defined $_[4] ?   $_[4]  :  0;

    my $Tlevel = 0;
    while ( ($Ptext =~ /($self->{'config'}{'tpl_start'}([\w\W]*?)$self->{'config'}{'tpl_end'})/i) && ($Tlevel++ < $self->{'config'}{'max_level'}) ) {
        $self->form_func($self->subst_vars($self->subst_vars(substr($Ptext,0,index($Ptext,$1)),\%Pvars_values),\%{$self->{'subst_values'}}));
        $Ptext = substr($Ptext,index($Ptext,$1)+length($1));
        my ($Ttag,$Trepeat) = $self->get_tag('tpl_repeat',$2, 1);
        ($Ttag,%Pvars_values) = $self->get_vars('tpl_vars',$Ttag,\%Pvars_values);
        ($Ttag,%Psql_values) = $self->get_vars('sql_vars',$self->subst_vars($Ttag,\%Pvars_values),\%Psql_values);
        for my $Tcount ( 1 .. $Trepeat) { $self->form_tag($Ttag,\%Psql_values,\%Pvars_values,($Tcount == 1 ? ++$Plevel : $Plevel)); }
    }
    $self->form_func($self->subst_vars($self->subst_vars($Ptext,\%Pvars_values),\%{$self->{'subst_values'}}));
}
############################################################################
#   END - FUNCTION form_tpl
############################################################################

############################################################################
#   BEGIN - FUNCTION form_func
#   input params:
#       0: text
#   Created   : 2004-12-13
#   Modified  : 2005-01-11
############################################################################
sub form_func {                                                             # @METAGS form_func
    my $self = $_[0];
    my $Ptext  = defined $_[1] ? $_[1]  : '';
    my $Tlevel = 0;
    while ( ($Ptext =~ /($self->{'config'}{'fnc_start'}([\w\W]*?)$self->{'config'}{'fnc_end'})/i) && ($Tlevel++ < $self->{'config'}{'max_level'}) ) {
        print $self->cp($self->replace_vars(substr($Ptext,0,index($Ptext,$1)),$self->{'config'}{'replace'}));
        $Ptext = substr($Ptext,index($Ptext,$1)+length($1));
        if ( defined &{$2} ) {
            eval($2);
        } else {
            my $Tfunc = '';
            my ($Ttag,%Tvars_values) = $self->get_vars('tpl_vars',$2);
            if ( $self->file($Ttag,$self->{'config'}{'FNCEXT'},$self->{'config'}{'FNCDIR'},'e') ) {
                open(FNC,"< ".$self->file($Ttag,$self->{'config'}{'FNCEXT'},$self->{'config'}{'FNCDIR'})) || die 'Error opening fnc file '.$self->file($Ttag,$self->{'config'}{'FNCEXT'},$self->{'config'}{'FNCDIR'});
                while ( my $Tline = <FNC> ) {
                    if ( $Tline !~ /^#/ ) {
                        ($Tline) = ($Tline =~ /(.*)/);
                        $Tfunc .= $Tline;
                    }
                }
                close(FNC);
            }
            if ( $Tfunc eq '' ) {
                my %Tvalues = (tag => $Ttag);
                my @Ttag = defined $self->{'config'}{'sql_tag_site'} ? $self->rtrim($self->{'config'}{'sql_tag_site'} ne '') ? $self->select_any($self->{'config'}{'sql_tag_site'}, \%Tvalues) : () : ();
                $Tfunc = defined $Ttag[0]->{'func'} ? $Ttag[0]->{'func'} : '';
            }
            if ($Tfunc eq '') { $Tfunc = defined $self->{'config'}{'fnc_tag_'.$2} ? $self->{'config'}{'fnc_tag_'.$Ttag} : ''; }

            eval($self->replace_vars($self->subst_vars($self->subst_vars($Tfunc,\%Tvars_values),\%{$self->{'subst_values'}}),$self->{'config'}{'replace'}));
        }
    }
    print $self->cp($self->replace_vars($Ptext,$self->{'config'}{'replace'}));
}
############################################################################
#   END - FUNCTION form_fnc
############################################################################


############################################################################
#   BEGIN - FUNCTION select_any
#       executes select statement and returns array of hash variables, one
#       for each row
#   input params:
#       1: sql select statement
#       2: variables to substitute inside sql statement
#   output params:
#       0: array of hash variables
#   Created   : 2004-11-20
#   Modified  : 2004-12-02
############################################################################
sub select_any {                                                            # @METAGS select_any
    my $self = $_[0];
    if ( !defined $_[1] ) {
        $self->error('Missing params');
    } else {
        my $Psql = $_[1];
        my $Psql_values = defined $_[2] ? $_[2] : ();

        my $Ttag = '';
        ($Psql, $Ttag) = split /\#/, $Psql;
        $Ttag = defined $Ttag ? ($self->rtrim($Ttag) ne '' ? $Ttag : $self->{'config'}{'main_db'}) : $self->{'config'}{'main_db'};
        if ( !defined $self->{'dbh'}{$Ttag} ) { $self->{'dbh'} = {$self->connect($Ttag,\%{$self->{'dbh'}})}; }
        my $Pdbh = $self->{'dbh'}{$Ttag};

        if ( defined $Psql_values ) { $Psql = $self->subst_vars($Psql,\%{$Psql_values},$Pdbh); }
        $Psql = $self->subst_vars($Psql,\%{$self->{'subst_values'}});

        $Psql =~ s/\r\n/ /g;
        $Psql =~ s/\n/ /g;

        my @Tfields = ();
        my ($Tfields_text) = ($Psql =~ /select\s*(.*?)\s*from/i);
        while ( $Tfields_text =~ / _(.*)/ ) {
            $Tfields_text = $1;
            if ( $Tfields_text =~ /(.*?),.*? _/ ) { push(@Tfields, $1           ); }
            else                                  { push(@Tfields, $Tfields_text); }
        }

        my @Tvalues = ();
        my $sth = $Pdbh->prepare($Psql) || die $Pdbh->errstr();
        $sth->execute() || die $sth->errstr();
        my $Tresults = $sth->fetchall_arrayref;
        $sth->finish();
        for my $i ( 0 .. $#{$Tresults} ) {
            $Tvalues[$i]->{'sql_row_no'} = $i+1;
            for my $j ( 0 .. $#Tfields ) {
                $Tvalues[$i]->{$Tfields[$j]} = defined $Tresults->[$i][$j] ? $Tresults->[$i][$j] : '';
            }
        }
        return @Tvalues;
    }
}
############################################################################
#   END - FUNCTION select_any
############################################################################


############################################################################
#   BEGIN - FUNCTION execute_any
#       executes any sql statement
#   input params:
#       1: sql select statement
#       2: variables to substitute inside sql statement
#   Created   : 2005-03-20
#   Modified  : 2005-03-20
############################################################################
sub execute_any {                                                           # @METAGS execute_any
    my $self = $_[0];
    if ( !defined $_[1] ) {
        $self->error('Missing params');
    } else {
        my $Psql = $_[1];
        my $Psql_values = defined $_[2] ? $_[2] : ();

        my $Ttag = '';
        ($Psql, $Ttag) = split /\#/, $Psql;
        $Ttag = defined $Ttag ? ($self->rtrim($Ttag) ne '' ? $Ttag : $self->{'config'}{'main_db'}) : $self->{'config'}{'main_db'};
        if ( !defined $self->{'dbh'}{$Ttag} ) { $self->{'dbh'} = {$self->connect($Ttag,\%{$self->{'dbh'}})}; }
        my $Pdbh = $self->{'dbh'}{$Ttag};

        if ( defined $Psql_values ) { $Psql = $self->subst_vars($Psql,\%{$Psql_values},$Pdbh); }
        $Psql = $self->subst_vars($Psql,\%{$self->{'subst_values'}});

        $Psql =~ s/\r\n/ /g;
        $Psql =~ s/\n/ /g;

        my $sth = $Pdbh->prepare($Psql) || die $Pdbh->errstr();
        $sth->execute() || die $sth->errstr();
        $sth->finish();

        if ( $Psql =~ /insert into/ ) {
            $sth = $Pdbh->prepare('select last_insert_id()') || die $Pdbh->errstr();
            $sth->execute() || die $sth->errstr();
            my $Tresult = $sth->fetchall_arrayref->[0][0];
            $sth->finish();
            return $Tresult;
        }
    }
}
############################################################################
#   END - FUNCTION execute_any
############################################################################


############################################################################
#   BEGIN - FUNCTION get_tag
#       gets next tag name from text
#   input params:
#       0: tag type
#       0: text in wich to find next tag name
#   output params:
#       0: tag name
#   Created : 2004-01-31
#   Modified: 2004-11-23
############################################################################
sub get_tag {                                                               # @METAGS get_tag
    my $self = $_[0];
    my $Ptype  = defined $_[1] ? $_[1] : '';
    my $Ptag   = defined $_[2] ? $_[2] : '';
    my $Pvalue = defined $_[3] ? $_[3] : '';
    if ( $Ptag =~ /($self->{'config'}{$Ptype.'_start'}(.*?)$self->{'config'}{$Ptype.'_end'})/i ) {
        $Pvalue = $2;
        $Ptag   =~ s/$1//;
    }
    return  ($Ptag, $Pvalue);
}
############################################################################
#   END - FUNCTION get_tag
############################################################################


############################################################################
#   BEGIN - FUNCTION get_vars
#       gets vars for the next tpl
#   input params:
#       0: text in wich to find next tpl variables values
#   output params:
#       0: text without vars statement
#       1: hash variable
#   Created : 2004-02-14
#   Modified: 2004-11-23
############################################################################
sub get_vars {                                                              # @METAGS get_vars
    my $self = $_[0];
    my $Ptype   = defined $_[1] ?   $_[1]  : '';
    my $Ptag    = defined $_[2] ?   $_[2]  : '';
    my %Pvars   = defined $_[3] ? %{$_[3]} : ();

    $Ptag =~ s/\r\n\s*//g;
    $Ptag =~ s/\n\s*//g;
    $Ptag =~ s/\r\n//g;
    $Ptag =~ s/\n//g;
    $Ptag =~ s/\(/_LBRAQ_/g;
    $Ptag =~ s/\)/_RBRAQ_/g;
    if ( $Ptag =~ /($self->{'config'}{$Ptype.'_start'}([\w\W]*?)$self->{'config'}{$Ptype.'_end'})/i ) {
        my @Tvars = split /\;/,$2;
        $Ptag =~ s/$1//;
        foreach my $Tvar (@Tvars) {
            $Tvar =~ s/_LBRAQ_/\(/g;
            $Tvar =~ s/_RBRAQ_/\)/g;
            $Pvars{substr($Tvar,0,index($Tvar,'='))} = $self->subst_vars(substr($Tvar,index($Tvar,'=')+1),\%Pvars);
        }
    }
    return ($Ptag, %Pvars);
}
############################################################################
#   END - FUNCTION get_vars
############################################################################


############################################################################
#   BEGIN - FUNCTION subst_vars
#       substitutes variables inside text variable, and returns text variable
#   input params:
#       0: text variable
#       1: hash containing variables
#   output params:
#       0: generated text variable
#   Created : 2003-04-26
#   Modified: 2005-04-09
############################################################################
sub subst_vars {                                                            # @METAGS subst_vars
    my $self = $_[0];
    my $Ptext    = defined $_[1] ? $_[1] : '';
    my $Pvars    = defined $_[2] ? $_[2] : ();

    my $Ttext = '';
    if ( defined $Ptext ) {
        $Ttext = $Ptext;
        if ( defined $Pvars ) {
            foreach my $Tkey (keys %{$Pvars}) {
                my $Tvar = '&'.$self->uc($Tkey);
                my $Tvalue = $self->cp($Pvars->{$Tkey});
                $Ttext =~ s/$Tvar/$Tvalue/g;
                $Tvar = '\$'.$self->uc($Tkey);
                $Ttext =~ s/$Tvar/$Tvalue/g;
            }
        }
    }
    return $Ttext;
}
############################################################################
#   END - FUNCTION subst_vars
############################################################################


############################################################################
#   BEGIN - FUNCTION replace_vars
#       replaces text parts inside text
#   input params:
#       0: text variable
#       1: replace variable
#   output params:
#       0: generated text variable
#   Created : 2005-04-09
#   Modified: 2005-04-09
############################################################################
sub replace_vars {                                                          # @METAGS replace_vars
    my $self = $_[0];
    my $Ptext    = defined $_[1] ? $_[1] : '';
    my $Preplace = defined $_[2] ? $_[2] : '';

    foreach my $Treplacement ( split /,/,$Preplace ) {
        my $Treplaced = 0;
        foreach my $Tcase ( split /\//,$Treplacement ) {
            my ($Tname, $Tvalue) = split /\#/,$Tcase;
            if ( !$Treplaced && ($Ptext =~ /$Tname/) ) {
                $Ptext =~ s/$Tname/$Tvalue/g;
                $Treplaced = 1;
            }
        }
    }
    return $Ptext;
}
############################################################################
#   END - FUNCTION replace_vars
############################################################################


############################################################################
#   BEGIN - FUNCTION subst_langs
#       substitutes variables inside text variable, and returns text variable
#   input params:
#       0: text variable
#       1: hash containing variables
#   output params:
#       0: generated text variable
#   Created : 2003-04-26
#   Modified: 2003-04-26
############################################################################
sub subst_langs {                                                            # @METAGS subst_langs
    my $self = $_[0];
    my $Ptext = defined $_[1] ? $_[1] : '';
    my $Pvars = defined $_[2] ? $_[2] : ();

    my $Ttext = '';
    if ( defined $Ptext ) {
        $Ttext = $Ptext;
        if ( defined $Pvars ) {
            foreach my $Tkey (keys %{$Pvars}) {
                my $Tvar = '\<'.$self->uc($Tkey).'\>';
                my $Tvalue = $self->cp($Pvars->{$Tkey});
                $Tvalue =~ s/\n$//gm;
                $Ttext =~ s/$Tvar/$Tvalue/g;
            }
        }
    }
    return $Ttext;
}
############################################################################
#   END - FUNCTION subst_langs
############################################################################


############################################################################
#   BEGIN - FUNCTION cp
#       replaces win-1250 š,ž,Š,Ž with iso-8859-2 ¹,¾,©,®
#   input params:
#       0: value to replace
#   output params:
#       0: replaced value
#   Created : 2002-07-10
#   Modified: 2002-07-10
############################################################################
sub cp {                                                                    # @METAGS cp
    my $self = $_[0],
    my $Ptext   = defined $_[1] ? $_[1] : '';
    $Ptext =~ s/š/¹/g;
    $Ptext =~ s/±/¹/g;
    $Ptext =~ s/&#154;/¹/g;
    $Ptext =~ s/&#261;/¹/g;
    $Ptext =~ s/ž/¾/g;
    $Ptext =~ s/µ/¾/g;
    $Ptext =~ s/&#318;/¾/g;
    $Ptext =~ s/&#158;/¾/g;
    $Ptext =~ s/Š/©/g;
    $Ptext =~ s/Ž/®/g;
    $Ptext =~ s/&#269;/è/g;
    return $Ptext;
}
############################################################################
#   END - FUNCTION cp
############################################################################


############################################################################
#   BEGIN - FUNCTION error
#       terminates program execution and returnes error (this should be upgraded to some kind of error log)
#   input params:
#       0: database handle
#       1: error type
#   Created : 2002-05-20
#   Modified: 2003-05-16
############################################################################
sub error {                                                                 # @METAGS error
    my $self = $_[0];
    my $Pmessage = '';
    if ( defined $_[1] ) { $Pmessage = $_[1]; }

    my $Tfile = (caller(1))[1];
    my $Tline = (caller(1))[2];
    my $Tproc = (caller(1))[3];

    my $Tscript_name = $ENV{'SCRIPT_NAME'};

    $self->free;
    die "$Pmessage at line $Tline in $Tfile, proc $Tproc ($Tscript_name).\n";
}
############################################################################
#   END - FUNCTION error
############################################################################


############################################################################
#   BEGIN - FUNCTION rtrim
#       removes trailing spaces from text
#   input params:
#       0: text
#   output params:
#       0: converted text
#   Created : 2002-07-27
#   Modified: 2002-07-27
############################################################################
sub rtrim {                                                                 # @METAGS rtrim
    my $self = $_[0];
    my $Ttext = '';
    if ( defined $_[1] ) {
        $Ttext = $_[1];
        $Ttext =~ s/\s*$//;
    }
    return $Ttext;
}
############################################################################
#   END - FUNCTION rtrim
############################################################################


############################################################################
#   BEGIN - FUNCTION ltrim
#       removes leading spaces from text
#   input params:
#       0: text
#   output params:
#       0: converted text
#   Created : 2002-11-20
#   Modified: 2002-11-20
############################################################################
sub ltrim {                                                                 # @METAGS ltrim
    my $self = $_[0];
    my $Ttext = '';
    if ( defined $_[1] ) {
        $Ttext = $_[1];
        $Ttext =~ s/^\s*//;
    }
    return $Ttext;
}
############################################################################
#   END - FUNCTION ltrim
############################################################################


############################################################################
#   BEGIN - FUNCTION file
#       checks file existance or returns its name
#   input params:
#       0: file path
#       1: file name
#       2: file ext
#       3: action
#   Created : 2005-02-19
#   Modified: 2005-02-19
############################################################################
sub file {                                                                  # @METAGS file
    my $self = $_[0];

    my $Pname   = defined $_[1] ? $_[1] : '' ;
    my $Pext    = defined $_[2] ? $_[2] : '' ;
    my $Ppath   = defined $_[3] ? $_[3] : '' ;
    my $Paction = defined $_[4] ? $_[4] : 'n';

    my $Tresult = $Paction eq 'e' ? 0 : $Ppath.$Pname.$Pext;
    if ( $self->rtrim($Ppath.$Pname.$Pext) ne '' ) {
        if ( -e $Ppath.$Pname.$Pext ) {
            $Tresult = $Paction eq 'e' ? 1 : $Ppath.$Pname.$Pext;
        } elsif ( -e $Ppath.$self->{'config'}{'CLSDIR'}.$Pname.$Pext ) {
            $Tresult = $Paction eq 'e' ? 1 : $Ppath.$self->{'config'}{'CLSDIR'}.$Pname.$Pext;
        } elsif ( -e $Ppath.$self->{'config'}{'TBLDIR'}.$Pname.$Pext ) {
            $Tresult = $Paction eq 'e' ? 1 : $Ppath.$self->{'config'}{'TBLDIR'}.$Pname.$Pext;
        }
    }
    return $Tresult;
}
############################################################################
#   END - FUNCTION file
############################################################################


1;
