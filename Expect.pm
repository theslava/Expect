# Please see README for documentation. This module is copyrighted
# as per the usual perl legalese:
# Copyright (c) 1997 Austin Schutz. All rights reserved. This program is free
# software; you can redistribute it and/or modify it under the same terms as
# Perl itself.
#
# Don't blame/flame me if you bust your stuff.
# Austin Schutz -  tex@habit.com

require 5; # 4 won't cut it. 

package Expect;

use IO::Pty; # This appears to require 5.004
use IO::Stty;

#use strict 'refs';
use strict 'vars';
use strict 'subs';
use POSIX; # For setsid. 
use Fcntl; # For checking file handle settings.

# This is necessary to make routines within Expect work.

@Expect::ISA= qw(IO::Pty);

BEGIN {
  $Expect::VERSION="1.01";
  # These are defaults which may be changed per object, or set as
  # the user wishes.
# This will be unset, since the default behavior differs between 
# spawned processes and initialized filehandles.
#  $Expect::Log_Stdout=1;
  $Expect::Log_Group=1;
  $Expect::Debug=0;
  $Expect::Exp_Internal=0;
  $Expect::Manual_Stty=0;
  $Expect::Use_Regexps=1;
}

sub version {
  my($version)=shift;
  warn "Version $version is later than $Expect::VERSION. It may not be supported" if (defined ($version) && ($version > $Expect::VERSION));

  die "Versions before .99 are not supported in this release" if ((defined ($version)) && ($version < .99));
  return $Expect::VERSION;
}

sub new { goto &spawn; }# We should be called as Expect->spawn or spawn Expect

sub spawn {
  my($tty);
  my($name_of_tty);
  my ($class)=shift;
  # Create the pty which we will use to pass process info.
  my($self) = new IO::Pty;
  bless ($self,$class);
  my($cmd) = join(' ',@_); # spawn is passed command line args.
  $name_of_tty= $self->IO::Pty::ttyname();
  die "$class: Could not assign a pty" unless $self->IO::Pty::ttyname();
  $self->IO::Pty::autoflush();
  # This is defined here since the default is different for initialized
  # handles as opposed to spawned processes.
  ${*$self}{exp_Log_Stdout}=1;
  $self->_init_vars();
  ${*$self}{exp_Pid} = fork;
  unless (defined (${*$self}{exp_Pid})) {
    warn "Cannot fork: $!";
    return undef;
  }
  unless (${*$self}{exp_Pid}) {
    # Child
    # Create a new 'session', lose controlling terminal.
    POSIX::setsid() || warn "Couldn't perform setsid. Strange behavior may result.\n Problem: $!\n";
    $tty = $self->IO::Pty::slave(); # Create slave handle.
    $name_of_tty= $tty->ttyname();
    # We have to close everything and then reopen ttyname after to get
    # a controlling terminal.
    close($self);
    close STDIN; close STDOUT; close STDERR;
    open(STDIN,"<&". $tty->fileno()) || die "Couldn't reopen ". $name_of_tty ." for reading, $!\n";
    open(STDOUT,">&". $tty->fileno()) || die "Couldn't reopen ". $name_of_tty ." for writing, $!\n";
    open(STDERR,">&". fileno(STDOUT)) || die "Couldn't redirect STDERR, $!\n";
    exec ($cmd);
# End Child.
  }

# Parent

  if ((${*$self}{"exp_Debug"})||(${*$self}{"exp_Exp_Internal"})) {
    print STDERR "Spawned '$cmd'\r\n";
    print STDERR "\tPid: ${*$self}{exp_Pid}\r\n";
    print STDERR "\tTty: ".$name_of_tty."\r\n";
  }
  # This is sort of for code compatibility, and to make debugging a little
  # easier. By code compatibility I mean that previously the process's
  # handle was referenced by $process{Pty_Handle} instead of just $process.
  # This is almost like 'naming' the handle to the process.
  # I think this also reflects Tcl Expect-like behavior.
  ${*$self}{exp_Pty_Handle}="spawn id(".$self->fileno().")";
  return $self;
}


sub exp_init {
  # take a filehandle, for use later with expect() or interconnect() .
  # All the functions are written for reading from a tty, so if the naming
  # scheme looks odd, that's why.
  my ($class)=shift;
  my($self) = shift;
  bless $self, $class;
  die "exp_init not passed a file object, stopped" unless defined($self->fileno());
# Define standard variables.. debug states, etc.
  $self->_init_vars();
  # Turn of logging. By default we don't want crap from a file to get spewed
  # on screen as we read it.
  ${*$self}{exp_Log_Stdout}=0;
  ${*$self}{exp_Pty_Handle}="handle id(".$self->fileno().")";
  print STDERR "Initialized ${*$self}{exp_Pty_Handle}.'\r\n" if ${*$self}{"exp_Debug"};
  return $self;
}



# We're happy OOP people. No direct access to stuff.
sub debug {
  my($self)=shift;
  return ${*$self}{"exp_Debug"} unless defined($_[0]);
  ${*$self}{"exp_Debug"} = shift;
}

sub exp_internal {
  my($self)=shift;
  return ${*$self}{"exp_Exp_Internal"} unless defined($_[0]);
  ${*$self}{"exp_Exp_Internal"} = shift;
}

sub log_stdout {
  my($self)=shift;
  return ${*$self}{"exp_Log_Stdout"} unless defined($_[0]);
  ${*$self}{"exp_Log_Stdout"} = shift;
}

sub log_group {
  my($self)=shift;
  return ${*$self}{"exp_Log_Group"} unless defined($_[0]);
  ${*$self}{"exp_Log_Group"} = shift;
}

sub pid {
  my($self)=shift;
  return (${*$self}{exp_Pid}) if defined ${*$self}{exp_Pid};
  return undef; # This would probably happen anyway.
}

# This has been modified. Really, it should just go away. This is here
# so .99 scripts won't fail.
sub exp_close {
  my($self)=shift;
  close($self);
}

# This is also obsolete.
sub exp_kill {
  my ($self)=shift;
  return undef unless defined (${*$self}{exp_Pid});
  my($signal)=shift;
  $signal=POSIX::SIGTERM unless defined($signal);
  kill ($signal,${*$self}{exp_Pid})
}

sub set_seq {
  # Set an escape sequence/function combo for a read handle for interconnect.
  # Ex: $read_handle->set_seq('',\&function,\@parameters); 
  my($self)=shift;
  my($caller)=(caller)[0];
  my($escape_sequence,$function)=(shift,shift);
  ${${*$self}{exp_Function}}{$escape_sequence}=$function;
  if((!defined($function))||($function eq 'undef')) {
    ${${*$self}{exp_Function}}{$escape_sequence}=\&_undef;
  }
  ${${*$self}{exp_Parameters}}{$escape_sequence}=shift;
# This'll be a joy to execute. :)
  print STDERR "Escape seq. '"._make_readable($escape_sequence)."' function for ${*$self}{exp_Pty_Handle} set to '${${*$self}{exp_Function}}{$escape_sequence}(".join(',',@_).")'\r\n" if ${*$self}{"exp_Debug"};
}

sub set_group {
  my($self)=shift;
  my($write_handle);
  # Make sure we can read from the read handle
  if(! defined($_[0])) {
    if (defined (${*$self}{exp_Listen_Group})) {
      return @{${*$self}{exp_Listen_Group}};
    } else {
      return undef;
    }
  }
  @{${*$self}{exp_Listen_Group}}=();
  if($self->_get_mode()!~'r') {
    warn "Attempting to set a handle group on ${*$self}{exp_Pty_Handle}, a non-readable handle!\r\n";
  }
  while($write_handle = shift) { 
    if ($self->_get_mode()!~'w') {
       warn "Attempting to set a non-writeable listen handle ${*$write_handle}{exp_Pty_handle} for ${*$self}{exp_Pty_Handle}!\r\n";
    }
  push (@{${*$self}{exp_Listen_Group}},$write_handle);
  }
}
  
sub use_regexps {
# Do regular expression matching during expect().
  my($self)=shift;
  return ${*$self}{"exp_Use_Regexps"} unless defined($_[0]);
  ${*$self}{"exp_Use_Regexps"} = shift;
}

sub manual_stty {
# Let user do own stty setting. Return the name of the tty to use.
  my($self)=shift;
  return ${*$self}{"exp_Manual_Stty"} unless defined($_[0]);
  ${*$self}{"exp_Manual_Stty"} = shift;
}

sub max_accum {
  my($self)=shift;
  return ${*$self}{"exp_Max_Accum"} unless defined($_[0]);
  ${*$self}{"exp_Max_Accum"}=shift;
  if (${*$self}{"exp_Max_Accum"} eq 'undefine') {
    undef(${*$self}{"exp_Max_Accum"});
  }
}

# I'm going to leave this here in case I might need to change something.
# Previously this was calling `stty`, in a most bastardized manner.
sub exp_stty {
  my($self)=shift;
  my($mode)=shift;
  return undef unless defined($mode);
  if (${*$self}{"exp_Debug"}) {
    print STDERR "Setting ${*$self}{exp_Pty_Handle} to tty mode '$mode'\n";
  }
  IO::Stty::stty($self,split(/\s/,$mode));
}

# If we want to clear the buffer. Otherwise Accum will grow during send_slow
# etc. and contain the remainder after matches.
sub clear_accum {
  my($self)=shift;
  my ($temp)=(${*$self}{exp_Accum});
  ${*$self}{exp_Accum}='';
# return the contents of the accumulator.
  return $temp;
}

sub expect {
  my ($self)=shift; 
  my($endtime, @patterns) = @_;
  my($successful_pattern,$pattern_number)=(0,0);
  my($match, $before, $after, $err);
  my($rmask, $nfound, $nread);
  my($dont_continue,$match_forever);
  my($no_regexp_match_index,$pattern,$matched_successfully);
  my($name_of_pty_handle);
  my($fileno);
  $match_forever=1 unless defined($endtime);
  # This makes debugging a little easier.
  if ($self->fileno() == fileno(STDIN)) {
    $name_of_pty_handle='STDIN';
  } else {
    $name_of_pty_handle=${*$self}{exp_Pty_Handle};
  }
  print STDERR "Beginning expect from $name_of_pty_handle.\r\nAccumulator: '"._trim_length(_make_readable((${*$self}{exp_Accum})))."'\r\n" if ${*$self}{"exp_Debug"};

  # Flush for log_stdout
  select((select($self),$|=1)[0]);
  $|=1;

  # Let's get the time here so there won't be any inconsistencies between
  # here and READLOOP.
  my ($time)=time;
  print STDERR "Expect timeout time: ".(defined($endtime) ? $endtime : "unlimited" )." seconds.\r\n" if ${*$self}{"exp_Debug"};
  # What happens if we want to go for 0 secs? We do a quick test on what is
  # ready on the handle.
  $dont_continue = 1 if ((!($match_forever))&&(!($endtime)));
  $endtime += $time if defined($endtime);
  print STDERR "expect: Pty=$name_of_pty_handle, time=",time,", endtime=".(defined($endtime) ? $endtime : "undef")."\r\n" if ${*$self}{"exp_Debug"};

# What are we expecting? What do you expect? :-)
  if (${*$self}{"exp_Exp_Internal"}) {
    print STDERR "Expecting (with";
    if (!${*$self}{exp_Use_Regexps}) {
      print STDERR "out";
    }
    print STDERR " regexp matching) from $name_of_pty_handle:";
    foreach $pattern (@patterns) {
      print STDERR " '".$pattern."'";
    }
    print STDERR "\r\n";
  }

# Loop until we get a match or time runs out.
READLOOP:
# Notice we only give ourselves a one second granularity. This could probably
# change if we wanted to rig an alarm or something like that.
# Since we allow for instant checks I think it should be okay.
  while (($match_forever)||($time <= $endtime)) {
    # Test for a match first so we can test the current Accum w/out worrying
    # about an EOF.
    if (defined(${*$self}{"exp_Max_Accum"})) {
      ${*$self}{exp_Accum}=_trim_length(${*$self}{exp_Accum},${*$self}{"exp_Max_Accum"});
    }
    if ( defined(${*$self}{exp_Accum}) && ${*$self}{exp_Accum} ne '' ) {
      $pattern_number = 1;
      # Give users visible control chars.
      if (${*$self}{"exp_Exp_Internal"}) {
        $_=_trim_length(_make_readable(${*$self}{exp_Accum}));
        print STDERR "Does '$_'\r\nfrom $name_of_pty_handle match:\r\n";
# This could be huge. We should attempt to do something about this. 
# Because the output is used for debugging I'm of the opinion that showing
# smaller amounts if the total is huge should be ok.
      }
      for $pattern ( @patterns ) {
        print STDERR "\tpattern $pattern_number \('$pattern'\)? " if (${*$self}{"exp_Exp_Internal"});
        # Matching exactly
        if (!${*$self}{exp_Use_Regexps}) {
          $no_regexp_match_index = index(${*$self}{exp_Accum},$pattern);
          # We matched if $no_regexp_match_index > -1
          if ($no_regexp_match_index > -1) {
            $before = substr(${*$self}{exp_Accum},0,$no_regexp_match_index);
            $match = substr(${*$self}{exp_Accum},$no_regexp_match_index,
              length($pattern));
            $after = substr(${*$self}{exp_Accum},
              $no_regexp_match_index + length($pattern)) ;
            $successful_pattern=$pattern_number;
          }
        } elsif ( ${*$self}{exp_Accum} =~ $pattern ) {
          ( $match, $before, $after ) = ( $&, $`, $' );
          $successful_pattern=$pattern_number;
        }
        if ($successful_pattern) {
          ${*$self}{exp_Accum} = $after;
          print STDERR "Yes!\r\n" if (${*$self}{"exp_Exp_Internal"});
          # The exclamation point makes it stick out. And gets me excited.
          if ((${*$self}{"exp_Exp_Internal"})||(${*$self}{"exp_Debug"})) {
            print STDERR "Matched pattern $successful_pattern ";
            print STDERR "(\'$pattern\')!\r\n";
            print STDERR "\tBefore match string: '"._trim_length(_make_readable(($`)))."'\r\n";
            print STDERR "\tMatch string: '"._make_readable($&)."'\r\n";
            print STDERR "\tAfter match string: '"._trim_length(_make_readable(($')))."'\r\n";
          }
  	  last READLOOP;
        }
        print STDERR "No.\r\n" if (${*$self}{"exp_Exp_Internal"});
        $pattern_number++; 
      }
    }
    # End of matching section

    $rmask = '';
    vec($rmask,$self->fileno(),1) = 1;
    # Do select for no time if only doing a quick pass.
    if ($dont_continue) {
      # Make sure we only go through once.
#      last READLOOP if ($dont_continue > 1); $dont_continue++;
      ($nfound, $rmask) = select($rmask, undef, undef, 0);
# Always go until we don't find something.
      last READLOOP unless $nfound;
      # If not found we will exit READLOOP at the end of the section.
      # We read in 20k for the quick pass. Don't want to miss anything.
      print STDERR "expect: handle $name_of_pty_handle ready.\r\n" if (${*$self}{"exp_Debug"});
      $nread = sysread($self, ${*$self}{exp_Pty_Buffer}, 2048);
      next READLOOP if $nread;# Iterate while we have stuff. 
    } else {
      if ($match_forever) {
        ($nfound) = select($rmask, undef, undef, undef);
      } else {
        ($nfound) = select($rmask, undef, undef, $endtime - $time);
      }
      # Track time here. One-time-through doesn't care about time.
      $time = time;
      # Try to be sure we won't miss anything because of inaccuracies in time 
      # measurement. Note that durations of less than a second will only
      # read in twice at the time of first info on the handle.
      # This is unavoidable because select doesn't return the time left on many
      # platforms. 
      if (defined ($endtime) && ($time >= $endtime)) {
        $time = $endtime;
        $dont_continue=1; # This generates a one-time-through loop.
      }
      last unless $nfound;
      print STDERR "expect: found ready handle $name_of_pty_handle.\r\n" if (${*$self}{"exp_Debug"} > 1);
      $nread = sysread($self, ${*$self}{exp_Pty_Buffer}, 2048);
    }
    $nread = 0 unless defined ($nread);
    print STDERR "expect: read $nread byte(s) from $name_of_pty_handle.\r\n" if (${*$self}{"exp_Debug"}>1);
    if ($nread > 0) {
      ${*$self}{exp_Accum} .= ${*$self}{exp_Pty_Buffer};
      # Show the user?
      $self->_print_handles(${*$self}{exp_Pty_Buffer});
    } elsif ($nread == 0) {
      $before = $self->clear_accum();
      $err = "2:EOF";
      last READLOOP;
    } else {
      print STDERR "Got an error reading from $name_of_pty_handle, $!\r\n" if (${*$self}{"exp_Debug"});
      $before=$self->clear_accum();
      $err = "4:".$!;
      last READLOOP;
    }
    # Last thing: Check to see if the process is dedsky.
    # for us to be read from the dead process.
# Sometimes the process is dying before we finish reading.
#    if (defined(${*$self}{exp_Pid})) {
#      waitpid(${*$self}{exp_Pid},POSIX::WNOHANG);
#      if ( !kill( 0, ${*$self}{exp_Pid} ) ) {
#        $before = $self->clear_accum();
#        $err = "3:${*$self}{exp_Pty_Handle} died";
#        last READLOOP;
#      }
#    }
    # Always end here if we're only passing through one time.
  }
# End READLOOP

# We're finished reading in. Have we matched anything?
  if ((!$successful_pattern) && (!$err)) {
    $before = ${*$self}{exp_Accum};
    # is it dead?
    if (defined(${*$self}{exp_Pid})) {
      waitpid(${*$self}{exp_Pid},WNOHANG);
      if ( !kill( 0, ${*$self}{exp_Pid} ) ) {
        $before = $self->clear_accum(); # Don't bother saving Accum. It's dead.
        $err = "3:Child process ${*$self}{exp_Pid} died before matching";
      }
    }
    $err = "1:TIMEOUT" unless $err;
  }

  if ($err) {
    $matched_successfully = "unsuccessfully: $err"
  } else {
    $matched_successfully = "successfully";
  }
  print STDERR "Returning from expect $matched_successfully.\r\n" if ${*$self}{"exp_Debug"} || ${*$self}{exp_Exp_Internal};
  unless($err) {
    print STDERR "Accumulator: '"._trim_length(_make_readable(${*$self}{exp_Accum}))."'\r\n" if ${*$self}{"exp_Debug"};
  } else {
    print STDERR "Accumulator: '"._trim_length(_make_readable($before))."'\r\n" if ${*$self}{"exp_Debug"};
  }
  $successful_pattern = undef if $err; # Sanity check
  if ( wantarray ) {
    return ( $successful_pattern, $err, $match, $before, $after );
  } else {
    return $successful_pattern;
  }
}

# $process->interact([$in_handle],[$escape sequence])
# If you don't specify in_handle STDIN  will be used.
sub interact {
  my ($self)=(shift);
  my ($infile)=(shift);
  my ($escape_sequence)=shift;
  my ($in_object,$in_handle,@old_group,$return_value);
  my ($old_manual_stty_val,$old_log_stdout_val);
  my ($outfile,$out_object);
  @old_group = $self->set_group();
  # If the handle is STDIN we'll
  # $infile->fileno == 0 should be stdin.. follow stdin rules.
  no strict 'subs'; # Allow bare word 'STDIN'
  unless (defined($infile)) {
    # We need a handle object Associated with STDIN.
    $infile = new IO::File;
    $infile->IO::File::fdopen(STDIN,'r');
    $outfile = new IO::File;
    $outfile->IO::File::fdopen(STDOUT,'w');
  } elsif (fileno($infile) == fileno(STDIN)) {
    # With STDIN we want output to go to stdout.
    $outfile = new IO::File;
    $outfile->IO::File::fdopen(STDOUT,'w');
  } else {
    undef ($outfile);
  }
  # Here we assure ourselves we have an Expect object.
  $in_object = Expect->exp_init($infile);
  if (defined($outfile)) {
    # as above.. we want output to go to stdout if we're given stdin.
    $out_object = Expect->exp_init($outfile);
    $out_object->manual_stty(1);
    $self->set_group($out_object);
  } else {
    $self->set_group($in_object);
  }
  $in_object->set_group($self);
  $in_object->set_seq($escape_sequence,undef) if defined($escape_sequence);
  # interconnect normally sets stty -echo raw. Interact really sort
  # of implies we don't do that by default. If anyone wanted to they could
  # set it before calling interact, of use interconnect directly.
  $old_manual_stty_val =$self->manual_stty();
  $self->manual_stty(1);
  # I think this is right. Don't send stuff from in_obj to stdout by default.
  # in theory whatever 'self' is should echo what's going on.
  $old_log_stdout_val=$self->log_stdout();
  $self->log_stdout(0);
  $in_object->log_stdout(0);
# Allow for the setting of an optional EOF escape function.
#  $in_object->set_seq('EOF',undef);
#  $self->set_seq('EOF',undef);
  Expect::interconnect($self,$in_object);
  $self->log_stdout($old_log_stdout_val);
  $self->set_group(@old_group);
  $self->manual_stty($old_manual_stty_val);
  return $return_value;
}

sub interconnect {

#  my ($handle)=(shift); call as Expect::interconnect($spawn1,$spawn2,...)
  my ($rmask,$nfound,$nread);
  my ($rout, @bits, $emask, $eout, @ebits ) = ();
  my ($escape_sequence,$escape_character_buffer,$offset);
  my (@handles)=@_;
  my ($handle,$read_handle,$write_handle);
  my ($read_mask,$temp_mask)=('','');

# Get read/write handles
  foreach $handle(@handles) {
    $temp_mask='';
    vec($temp_mask,$handle->fileno(),1) = 1;
    # Under Linux w/ 5.001 the next line comes up w/ 'Uninit var.'.
    # It appears to be impossible to make the warning go away.
    # doing something like $temp_mask='' unless defined ($temp_mask)
    # has no effect whatsoever. This may be a bug in 5.001.
    $read_mask= $read_mask | $temp_mask;
    select((select($handle),$|=1)[0]);
  }
  if($Expect::Debug) {
    print STDERR "Read handles:\r\n";
    foreach $handle(@handles) {
      print STDERR "\tRead handle: ";
      print STDERR "'${*$handle}{exp_Pty_Handle}'\r\n";
      print STDERR "\t\tListen Handles:";
      foreach $write_handle(@{${*$handle}{exp_Listen_Group}}) {
        print STDERR " '${*$write_handle}{exp_Pty_Handle}'";
      }
      print STDERR ".\r\n";
    }
  }

#  I think if we don't set raw/-echo here we may have trouble. We don't 
# want a bunch of echoing crap making all the handles jabber at each other.
  foreach $handle(@handles) {
    unless (${*$handle}{"exp_Manual_Stty"}) {
      # This is probably O/S specific.
      ${*$handle}{exp_Stored_Stty}=$handle->exp_stty('-g');
      print STDERR "Setting tty for ${*$handle}{exp_Pty_Handle} to 'raw -echo'.\r\n"if ${*$handle}{"exp_Debug"};
      $handle->exp_stty("raw -echo");
    }
    foreach $write_handle (@{${*$handle}{exp_Listen_Group}}) {
      unless (${*$write_handle}{"exp_Manual_Stty"}) {
        ${*$write_handle}{exp_Stored_Stty}=$write_handle->exp_stty('-g');
        print STDERR "Setting ${*$write_handle}{exp_Pty_Handle} to 'raw -echo'.\r\n"if ${*$handle}{"exp_Debug"};
        $write_handle->exp_stty("raw -echo");
      }
    }
  }

  print STDERR "Attempting interconnection\r\n" if $Expect::Debug;

# Wait until the process dies or we get EOF
# In the case of !${*$handle}{exp_Pid} it means
# the handle was exp_inited instead of spawned.
CONNECT_LOOP:
  # Go until we have a reason to stop
  while (1) {
# test each handle to see if it's still alive.
    foreach $read_handle (@handles) {
      waitpid(${*$read_handle}{exp_Pid}, WNOHANG) if (defined (${*$read_handle}{exp_Pid})&&${*$read_handle}{exp_Pid});
      if (defined(${*$read_handle}{exp_Pid})&&(${*$read_handle}{exp_Pid})&&(! kill(0,${*$read_handle}{exp_Pid}))) {
        print STDERR "Got EOF (${*$read_handle}{exp_Pty_Handle} died) reading ${*$read_handle}{exp_Pty_Handle}\r\n"if ${*$read_handle}{"exp_Debug"};
        last CONNECT_LOOP unless defined(${${*$read_handle}{exp_Function}}{"EOF"});
        last CONNECT_LOOP unless &{${${*$read_handle}{exp_Function}}{"EOF"}}(@{${${*$read_handle}{exp_Parameters}}{"EOF"}});
      }
    }

# Every second? No, go until we get something from someone.
    ($nfound) = select($rout=$read_mask, undef, $eout=$emask, undef);
    # Is there anything to share?
    next CONNECT_LOOP unless $nfound;
    # Which handles have stuff?
    @bits = split(//,unpack('b*',$rout));
    $eout= 0 unless defined ($eout);
    @ebits = split(//,unpack('b*',$eout));
#    print "Ebits: $eout\r\n";
    foreach $read_handle(@handles) {
      if ($bits[$read_handle->fileno()]) {
        $nread=sysread( $read_handle, ${*$read_handle}{exp_Pty_Buffer}, 1024 );
        # Appease perl -w
        ${*$read_handle}{"exp_Debug"}=0 unless defined (${*$read_handle}{"exp_Debug"});
        $nread = 0 unless defined ($nread);
        print STDERR "interconnect: read $nread byte(s) from ${*$read_handle}{exp_Pty_Handle}.\r\n" if ${*$read_handle}{"exp_Debug"}>1;
        # Test for escape seq. before printing.
        # Appease perl -w
        $escape_character_buffer = '' unless defined ($escape_character_buffer);
        $escape_character_buffer .=${*$read_handle}{exp_Pty_Buffer};
        foreach $escape_sequence (keys(%{${*$read_handle}{exp_Function}})) {
        print STDERR "Tested escape sequence $escape_sequence from ${*$read_handle}{exp_Pty_Handle}"if ${*$read_handle}{"exp_Debug"}>1;
          # Make sure it doesn't grow out of bounds.
          if ((defined(${*$read_handle}{"exp_Max_Accum"})&&(length($escape_character_buffer))>${*$read_handle}{"exp_Max_Accum"})) {
            $offset = length($escape_character_buffer) - ${*$read_handle}{"exp_Max_Accum"};
            $escape_character_buffer = substr($escape_character_buffer,$offset,${*$read_handle}{"exp_Max_Accum"});
          }
          if ($escape_character_buffer =~ /($escape_sequence)/) {
            if (${*$read_handle}{"exp_Debug"}) {
              print STDERR "\r\ninterconnect got escape sequence from ${*$read_handle}{exp_Pty_Handle}.\r\n";
              # I'm going to make the esc. seq. pretty because it will 
              # probably contain unprintable characters.
              print STDERR "\tEscape Sequence: '"._trim_length(_make_readable($escape_sequence))."'\r\n";
              print STDERR "\tMatched by string: '"._trim_length(_make_readable($&))."'\r\n";
            }
            # Print out stuff before the escape.
            # Keep in mind that the sequence may have been split up
            # over several reads.
            # Let's get rid of it from this read. If part of it was 
            # in the last read there's not a lot we can do about it now.
            if (${*$read_handle}{exp_Pty_Buffer}=~ /($escape_sequence)/) {
              $read_handle->_print_handles($`);
            } else {
              $read_handle->_print_handles(${*$read_handle}{exp_Pty_Buffer})
            }
            # Clear the buffer so no more matches can be made and it will
            # only be printed one time.
            ${*$read_handle}{exp_Pty_Buffer}='';
            $escape_character_buffer='';
            # Do the function here. Must return non-zero to continue.
            # More cool syntax. Maybe I should turn these in to objects.
            last CONNECT_LOOP unless &{${${*$read_handle}{exp_Function}}{$escape_sequence}}(@{${${*$read_handle}{exp_Parameters}}{$escape_sequence}});
          }
        }
        $nread = 0 unless defined($nread); # Appease perl -w?
        waitpid(${*$read_handle}{exp_Pid}, WNOHANG) if (defined (${*$read_handle}{exp_Pid})&&${*$read_handle}{exp_Pid});
        if ($nread == 0) {
          print STDERR "Got EOF reading ${*$read_handle}{exp_Pty_Handle}\r\n"if ${*$read_handle}{"exp_Debug"}; 
          last CONNECT_LOOP unless defined(${${*$read_handle}{exp_Function}}{"EOF"});
          last CONNECT_LOOP unless &{${${*$read_handle}{exp_Function}}{"EOF"}}(@{${${*$read_handle}{exp_Parameters}}{"EOF"}});
        }
        last CONNECT_LOOP if ($nread < 0); # This would be an error
        $read_handle->_print_handles(${*$read_handle}{exp_Pty_Buffer});
      }
      # I'm removing this because I haven't determined what causes exceptions
      # consistently.
      if (0)#$ebits[$read_handle->fileno()])
      {
        print STDERR "Got Exception reading ${*$read_handle}{exp_Pty_Handle}\r\n"if ${*$read_handle}{"exp_Debug"};
        last CONNECT_LOOP unless defined(${${*$read_handle}{exp_Function}}{"EOF"});
        last CONNECT_LOOP unless &{${${*$read_handle}{exp_Function}}{"EOF"}}(@{${${*$read_handle}{exp_Parameters}}{"EOF"}});
      }
    }
  }
  foreach $handle(@handles) {
    unless (${*$handle}{"exp_Manual_Stty"}) {
      $handle->exp_stty(${*$handle}{exp_Stored_Stty});
    }
    foreach $write_handle (@{${*$handle}{exp_Listen_Group}}) {
      unless (${*$write_handle}{"exp_Manual_Stty"}) {
        $write_handle->exp_stty(${*$write_handle}{exp_Stored_Stty});
      }
    }
  }
}


# This is an Expect standard. It's nice for talking to modems and the like
# where from time to time they get unhappy if you send items too quickly.
sub send_slow{
  my ($self)=shift;
  my($char,@linechars,$nfound,$rmask);
  my($sleep_time)=shift;
# Flushing makes it so each character can be seen separately.
  select((select($self),$|=1)[0]);
  $|=1;
  while ($_=shift) {
    @linechars = split ('');
    foreach $char (@linechars) {
#     How slow?
      select (undef,undef,undef,$sleep_time);

      print $self $char;
      print STDERR "Printed character \'"._make_readable($char)."\' to ${*$self}{exp_Pty_Handle}.\r\n" if ${*$self}{"exp_Debug"}>1;
      # I think I can get away with this if I save it in accum
      if (${*$self}{"exp_Log_Stdout"}||${*$self}{exp_Log_Group}) {
        $rmask = "";
        vec($rmask,$self->fileno(),1)=1;
        # .01 sec granularity should work. If we miss something it will
        # probably get flushed later, maybe in an expect call.
        while (select($rmask,undef,undef,.01)) {
          sysread($self,${*$self}{exp_Pty_Buffer},1024);
          # Is this necessary to keep? Probably.. #
          # if you need to expect it later.
          ${*$self}{exp_Accum}.=${*$self}{exp_Pty_Buffer};
          ${*$self}{exp_Accum}=_trim_length(${*$self}{exp_Accum},${*$self}{"exp_Max_Accum"}) if defined (${*$self}{"exp_Max_Accum"});
          $self->_print_handles(${*$self}{exp_Pty_Buffer});
          print STDERR "Received \'"._trim_length(_make_readable($char))."\' from ${*$self}{exp_Pty_Handle}\r\n" if ${*$self}{"exp_Debug"}>1;
        }
      }
    }
  }
}

sub test_handles {
  # This should be called by Expect::test_handles($timeout,@objects);
  my ($rmask, $allmask, $rout, $nfound, @bits, @return_list, $handle_num);
  my ($timeout)=shift;
  my (@handle_list)=@_;
  my($handle);
  foreach $handle (@handle_list) {
    $rmask = '';
    vec($rmask,$handle->fileno(),1) = 1;
    $allmask = '' unless defined ($allmask);
    $allmask = $allmask | $rmask;
  }
  ($nfound) = select($rout=$allmask, undef, undef, $timeout);
  return undef unless $nfound;
  # Which handles have stuff?
  @bits = split(//,unpack('b*',$rout));
  foreach $handle (@handle_list) {
    # I go to great lengths to get perl -w to shut the hell up.
    if (defined($bits[$handle->fileno()])&&($bits[$handle->fileno()])) {
      $handle_num = 0 unless defined($handle_num); # Have it return a numeric.
      push(@return_list,$handle_num);
    }
    $handle_num++;
  }
  return (@return_list);
}
    
# These should not be called externally.

sub _init_vars {
#  print join(' ',@_,"\n");exit;
  my($self)=shift;
# for every spawned process or filehandle.
  ${*$self}{"exp_Log_Stdout"}=$Expect::Log_Stdout if defined ($Expect::Log_Stdout);
  ${*$self}{"exp_Log_Group"}=$Expect::Log_Group;
  ${*$self}{"exp_Debug"}=$Expect::Debug;
  ${*$self}{"exp_Exp_Internal"}=$Expect::Exp_Internal;
  ${*$self}{"exp_Manual_Stty"}=$Expect::Manual_Stty;
  ${*$self}{exp_Stored_Stty}='sane';
  ${*$self}{exp_Use_Regexps}=$Expect::Use_Regexps;
  # sysread doesn't like my or local vars.
  ${*$self}{exp_Pty_Buffer}=''; 
}


sub _make_readable {
  $_=shift;
  $_='' unless defined ($_);
  study; # Speed things up?
  s/\\/\\\\/g; # So we can tell easily(?) what is a backslash
  s/\n/\\n/g;
  s/\r/\\r/g;
  s/\t/\\t/g;
  s/\0/\\0/g;
  s/\'/\\\'/g; # So we can tell whassa quote and whassa notta quote.
  s/\"/\\\"/g;
  # Backspace
  # s/\b/\\b/g; This isn't working too well.
  # Formfeed (does anyone use formfeed?)
  s/\f/\\f/g;
  # Delete
  s/\177/'^?'/g;
  # High / low ascii
  while(/([\200-\377\001-\037])/) {
    my ($equiv)=sprintf("%lo",ord($1));
    while (length ($equiv) < 3) {
      $equiv = '0'.$equiv;
    }
    s/[\200-\377\001-\037]/\\$equiv/; # Only match first one.
  }	
  return $_;
}

sub _trim_length {
  # This is sort of a reverse truncation function
  # Mostly so we don't have to see the full output when we're using
  # Also used if Max_Accum gets set to limit the size of the accumulator
  # for matching functions. 
  # exp_internal
  my($string)=shift;
  my($length)=shift;
  my($indicate_truncation)='...' unless $length;
  $length = 1021 unless $length;
  return($string) unless $length < length($string);
  # We wouldn't want the accumulator to begin with '...' if max_accum is passed
  # This is because this funct. gets called internally w/ max_accum
  # and is also used to print information back to the user.
  return $indicate_truncation.substr($string,(length($string)-$length),$length);
}

sub _print_handles {
  # Given crap from 'self' and the handles self wants to print to, print to
  # them. these are indicated by the handle's 'group'
  my($self)=shift;
  my($print_this)=shift;
  my($handle);
  if (${*$self}{exp_Log_Group}) {
    foreach $handle(@{${*$self}{exp_Listen_Group}}) {
      select((select($handle),$|=1)[0]);
      $print_this='' unless defined ($print_this);
      # Appease perl -w
      ${*$handle}{"exp_Debug"}=0 unless defined(${*$handle}{"exp_Debug"});
      print STDERR "Printed '"._trim_length(_make_readable($print_this))."' to ${*$handle}{exp_Pty_Handle} from ${*$self}{exp_Pty_Handle}.\r\n" if (${*$handle}{"exp_Debug"}>1);
      print $handle $print_this;
    }
  }
  # If ${*$self}{exp_Pty_Handle} is STDIN this would make it echo.
  print $print_this if ${*$self}{"exp_Log_Stdout"};
}

sub _get_mode {
  my($fcntl_flags)='';
  my($handle)=shift;
# What mode are we opening with? use fcntl to find out.
  $fcntl_flags=fcntl(\*{$handle},Fcntl::F_GETFL,$fcntl_flags);
  die "fcntl returned undef during exp_init of $handle, $!\r\n" unless defined($fcntl_flags);
  if($fcntl_flags|(Fcntl::O_RDWR)) {
    return 'rw';
  } elsif ($fcntl_flags|(Fcntl::O_WRONLY)) {
    return 'w'
  } else {
  # Under Solaris (among others?) O_RDONLY is implemented as 0. so |O_RDONLY would fail.
    return 'r';
  }
}


sub _undef {
 return undef;
# Seems a little retarded but &CORE::undef fails in interconnect.
# This is used for the default escape sequence function.
# w/out the leading & it won't compile.
}


END {
  # This page intentionally left blank
  # Actually there was a function in here that I moved. I may need this later.
}


__END__
