integer channel =   2;
integer rlvchan =   3333;
integer rlvchan_lsnr;
integer howlong;
list    timeouts;
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
    string  name    =   llGetObjectName();
    llSetObjectName( llGetScriptName() );
    llOwnerSay(      txt );
    llSetObjectName( name );
}

default
{
    state_entry()
    {
        llListen( channel,   "", llGetOwner(), "" );
    }
    changed( integer chg )
    {
        if ( chg & CHANGED_OWNER )
            llResetScript();
    }
    attach( key id )
    {
        if ( id != NULL_KEY )
        {
            say("@sendchannel:"+(string)channel+"=add");
        }
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
        timeouts        =   llDeleteSubList( timeouts, 0, 1 );
        if (folder != "")
        {
            say("Removing "+folder);
            say("@detachall:"+folder+"=force");
        }
        diff            =   llList2Integer( timeouts, 0 ) - llGetUnixTime();
        if ( diff > 0 )
            llSetTimerEvent( diff );
    }
    listen( integer ch, string name, key id, string msg )
    {
        if (ch == channel)
        {
            howlong         =   0;
            list    cmd     =   llParseString2List( msg, [" "], [] );
            string  a0      =   llList2String( cmd, 0 );
            string  a1      =   llList2String( cmd, 1 );
            if ( a0 != "qw" )
                return;
            msg             =   llDumpList2String( llDeleteSubList( cmd, 0, 1 ), "&&" );
            msg             =   stripstring(msg, ";");
            msg             =   stripstring(msg, "=");
            mode            =   MODE_NONE;
//          if ( a1 == "menu" )
//              mode        =   MODE_MENU;
            if ( a1 == "find" )
                mode        =   MODE_FIND;
            if ( a1 == "wear" )
                mode        =   MODE_WEAR;
            if ( a1 == "5" )
            {
                mode        =   MODE_WEAR;
                howlong     =   5 * 60;
            }
            if ( a1 == "1" )
            {
                mode        =   MODE_WEAR;
                howlong     =   1 * 60;
            }
            if ( a1 == "unwear" )
                mode        =   MODE_UNWEAR;
            // no valid choices
            if ( mode == MODE_NONE )
                return;
            rlvchan = (integer) llFrand(654321)+654321;
            llListenRemove( rlvchan_lsnr );
            llListen( rlvchan,   "", llGetOwner(), "" );
            say("@findfolders:" + msg + "=" + (string)rlvchan);
            return;
        }
        if (ch == rlvchan)
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
                        llSetTimerEvent( howlong );
                        timeouts    +=  [ llGetUnixTime()+howlong, msg ];
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
