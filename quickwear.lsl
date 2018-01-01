integer commandchannel  =   2;
integer viewerresponsechannel;
integer viewerresponsechannel_lsnr;
integer howlong;
list    timeouts;
integer is_locked_on;
integer mode            =   0;
integer MODE_NONE       =   0;
integer MODE_WEAR       =   1;
integer MODE_UNWEAR     =   2;
integer MODE_MENU       =   3;
integer MODE_FIND       =   4;

string  stripstring(string haystack, string needle)
{
    integer idx;
    while ( (idx = llSubStringIndex( haystack, needle ) > -1 ) )
    {
        haystack    =   llDeleteSubString( haystack, idx, idx );
    }
    return haystack;
}

say( string txt )
{
    string  myobjname   =   llGetObjectName();
    // In case we are placed in a prim together with other scripts, then
    // change the prim name while we say anything.
    llSetObjectName( llGetScriptName() );
    llOwnerSay(      txt );
    // When we're done talking, we rename the prim back to its previous name.
    llSetObjectName( myobjname );
}

default
{
    state_entry()
    {
        llListen( commandchannel,   "", llGetOwner(), "" );
        is_locked_on    =   0;
        say( "@clear" );
    }
    changed( integer chg )
    {
        if ( chg & CHANGED_OWNER )
            llResetScript();
    }
    attach( key id )
    {
        if ( id == NULL_KEY )
            return;
        // User just attached us,
        // so send a sendchannel exception to her viewer.
        say( "@sendchannel:" + (string)commandchannel + "=add" );
    }
    timer()
    {
        integer t       =   llList2Integer( timeouts, 0 );
        if ( t == 0 )
        {
            llSetTimerEvent( 0 );
            return;
        }
        integer diff    =   t - llGetUnixTime();
        if ( diff > 0 )
        {
            llSetTimerEvent( diff );
            return;
        }
        string  folder  =   llList2String( timeouts, 1 );
        if (folder != "") // sanity check
        {
            say( "Removing "   + folder );
            say( "@detachall:" + folder + "=force" );
        }
        timeouts        =   llDeleteSubList( timeouts, 0, 1 );
        // Let us get called really soon and if it is too soon, use the
        // logic already invented at the beginning of timer()
        llSetTimerEvent( 1.0 );
    }
    listen( integer ch, string name, key id, string msg )
    {
        if (ch == commandchannel)
        {
            // The listen only matches llGetOwner(), but to make it obvious...
            if ( id != llGetOwner() )
                return;
            howlong         =   0;
            mode            =   MODE_NONE;
            list    cmd     =   llParseString2List( msg, [" "], [] );
            string  a0      =   llList2String( cmd, 0 );
            string  a1      =   llList2String( cmd, 1 );
            // We demand this prefix to all commands.
            if ( a0 != "qw" )
                return;
            if ( a1 == "lock" )
            {
                is_rlv_locked = 1;
                say( "@detach=n" );
                say( "Locked on." );
                return;
            }
            else
            if ( a1 == "unlock" )
            {
                is_rlv_locked = 0;
                say( "@detach=y" );
                say( "Unlocked." );
                return;
            }
            else
            if ( a1 == "find" )
                mode        =   MODE_FIND;
            else
            if ( a1 == "wear" )
                mode        =   MODE_WEAR;
            else
            if ( a1 == "5" )
            {
                mode        =   MODE_WEAR;
                howlong     =   5 * 60;
            }
            else
            if ( a1 == "1" )
            {
                mode        =   MODE_WEAR;
                howlong     =   1 * 60;
            }
            else
            if ( a1 == "unwear" )
                mode        =   MODE_UNWEAR;
            // no valid choices
            else
            {
                say(
                    "Valid commands are:\n".
                    "  find  : searches for substrings in your #RLV\n".
                    "  wear  : searches as above and wears the resulting folder if there is just a single folder which matches.\n".
                    "  1     : As wear, but unwears the same folder after 1 minute.\n".
                    "  5     : As wear, but unwears the same folder after 5 minutes.\n"
                    "  unwear: Just as wear, just unwears instead.\n".
                    "  lock  : RLV locks the prim, so it can not be detached.\n".
                    "  unlock: Removes the RLV lock."
                );
                return;
            }
            // Every call to qw creates a new channel and discards the old.
            // This avoids old results matching with new issued searches.
            viewerresponsechannel = (integer) llFrand(654321)+654321;
            llListenRemove( viewerresponsechannel_lsnr );
            llListen( viewerresponsechannel,   "", llGetOwner(), "" );
            // Create the search string
            msg             =   llDumpList2String( llDeleteSubList( cmd, 0, 1 ), "&&" );
            // Remove ; from search strings, because they create problems
            msg             =   stripstring(msg, ";");
            // Remove = from search strings, because they create problems
            msg             =   stripstring(msg, "=");
            say("@findfolders:" + msg + "=" + (string)viewerresponsechannel);
            return;
        }
        if (ch == viewerresponsechannel)
        {
            if ( msg == "" )
            {
                llOwnerSay( "No matches.");
                return;
            }
            list    folders =   llParseString2List( msg, [","], []);
            integer matches =   llGetListLength( folders );
            if ( matches == 1 )
            {
                if ( mode == MODE_FIND )
                    say( "Found 1 match:\n  " + msg );
                else
                if ( mode == MODE_WEAR )
                {
                    say( "Wearing "        + msg );
                    say( "@attachallover:" + msg + "=force" );
                    if ( howlong )
                    {
                        // the timer event has code to properly figure out 
                        // what to set the llSetTimerEvent to.. so we just
                        // make sure it gets called.
                        llSetTimerEvent( 1.0 );
                        timeouts    =   llListSort(
                            timeouts + [ llGetUnixTime()+howlong, msg ],
                            2,      // stride
                            TRUE    // ascending sort
                        );
                    }
                }
                else
                if ( mode == MODE_UNWEAR )
                {
                    say( "Removing "   + msg );
                    say( "@detachall:" + msg + "=force" );
                }
                return;
            }
            else
            {
                string  info    =   "Found "+(string)matches+" matches";
                if ( mode == MODE_FIND )
                    info    +=  ":";
                else
                if ( mode == MODE_WEAR )
                    info    +=  ", so not wearing anything:";
                else
                if ( mode == MODE_UNWEAR )
                    info    +=  ", so not removing anything:";
                else
                    return;
                say( llDumpList2String( folders, "\n  "));
                return;
            }
        }
    }
}
