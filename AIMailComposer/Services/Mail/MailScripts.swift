import Foundation

enum MailScripts {
    static let fetchThread = """
    tell application "Mail"
        set rootMsg to missing value
        set debugInfo to ""

        -- Approach 1: try "selected messages" (modern Mail) and "selection" (older Mail)
        try
            set viewerCount to count of message viewers
            set debugInfo to debugInfo & "viewers:" & (viewerCount as string) & ";"
            repeat with i from 1 to viewerCount
                try
                    set sel to selected messages of message viewer i
                    set debugInfo to debugInfo & "v" & (i as string) & "sel:" & ((count of sel) as string) & ";"
                    if (count of sel) > 0 then
                        set rootMsg to item 1 of sel
                        exit repeat
                    end if
                on error
                    -- Try legacy "selection" property
                    try
                        set sel to selection of message viewer i
                        if (count of sel) > 0 then
                            set rootMsg to item 1 of sel
                            exit repeat
                        end if
                    end try
                end try
            end repeat
        on error errMsg
            set debugInfo to debugInfo & "viewer_err:" & errMsg & ";"
        end try

        -- Approach 2: if a compose window is open, get subject from outgoing message
        if rootMsg is missing value then
            try
                set outMsgCount to count of outgoing messages
                set debugInfo to debugInfo & "outgoing:" & (outMsgCount as string) & ";"
                if outMsgCount > 0 then
                    set outMsg to outgoing message 1
                    set composeSubject to subject of outMsg
                    set debugInfo to debugInfo & "compose_subj:" & composeSubject & ";"
                    set baseSubj to my stripPrefixes(composeSubject)
                    repeat with acct in accounts
                        if rootMsg is not missing value then exit repeat
                        repeat with mbName in {"INBOX", "Sent Messages", "Sent", "Gesendet", "Archive", "Archiv", "All Mail"}
                            if rootMsg is not missing value then exit repeat
                            try
                                set mb to mailbox mbName of acct
                                set matches to (every message of mb whose subject contains baseSubj)
                                if (count of matches) > 0 then
                                    set rootMsg to item 1 of matches
                                end if
                            end try
                        end repeat
                    end repeat
                end if
            on error errMsg
                set debugInfo to debugInfo & "outgoing_err:" & errMsg & ";"
            end try
        end if

        -- Approach 3: get the frontmost window name (it contains the subject) and search
        if rootMsg is missing value then
            try
                set winCount to count of windows
                set debugInfo to debugInfo & "windows:" & (winCount as string) & ";"
                if winCount > 0 then
                    set winName to name of window 1
                    set debugInfo to debugInfo & "win1:" & winName & ";"
                    -- Window name is typically the email subject
                    if winName is not "" and winName is not "New Message" then
                        set baseSubj to my stripPrefixes(winName)
                        repeat with acct in accounts
                            if rootMsg is not missing value then exit repeat
                            repeat with mbName in {"INBOX", "Sent Messages", "Sent", "Gesendet", "Archive", "Archiv", "All Mail"}
                                if rootMsg is not missing value then exit repeat
                                try
                                    set mb to mailbox mbName of acct
                                    set matches to (every message of mb whose subject contains baseSubj)
                                    if (count of matches) > 0 then
                                        set rootMsg to item 1 of matches
                                    end if
                                end try
                            end repeat
                        end repeat
                    end if
                end if
            on error errMsg
                set debugInfo to debugInfo & "win_err:" & errMsg & ";"
            end try
        end if

        if rootMsg is missing value then
            return "ERROR:NO_SELECTION|" & debugInfo
        end if

        -- Found a root message, now collect the thread
        set rootSubject to subject of rootMsg
        set rootMailbox to mailbox of rootMsg
        set baseSubject to my stripPrefixes(rootSubject)

        set threadMsgs to (every message of rootMailbox whose subject contains baseSubject)

        -- Also check Sent mailbox for our replies in the thread
        try
            set rootAccount to account of rootMailbox
            repeat with sentName in {"Sent Messages", "Sent", "Gesendet"}
                try
                    set sentMb to mailbox sentName of rootAccount
                    set sentMsgs to (every message of sentMb whose subject contains baseSubject)
                    set threadMsgs to threadMsgs & sentMsgs
                end try
            end repeat
        end try

        -- Limit to most recent 20 messages
        set msgCount to count of threadMsgs
        if msgCount > 20 then
            set threadMsgs to items (msgCount - 19) thru msgCount of threadMsgs
        end if

        set output to ""
        repeat with msg in threadMsgs
            set output to output & "FROM:" & (sender of msg) & linefeed
            try
                set recipientList to ""
                repeat with r in to recipients of msg
                    if recipientList is not "" then set recipientList to recipientList & ", "
                    set recipientList to recipientList & (address of r)
                end repeat
                set output to output & "TO:" & recipientList & linefeed
            on error
                set output to output & "TO:unknown" & linefeed
            end try
            set output to output & "SUBJECT:" & (subject of msg) & linefeed
            try
                set output to output & "DATE:" & (date sent of msg as string) & linefeed
            on error
                set output to output & "DATE:Unknown" & linefeed
            end try
            set output to output & "BODY_START" & linefeed
            try
                set output to output & (content of msg) & linefeed
            on error
                set output to output & "(unable to read body)" & linefeed
            end try
            set output to output & "BODY_END" & linefeed
            set output to output & "---END_MESSAGE---" & linefeed
        end repeat
        return output
    end tell

    on stripPrefixes(subj)
        set s to subj
        set changed to true
        repeat while changed
            set changed to false
            if s starts with "Re: " then
                set s to text 5 thru -1 of s
                set changed to true
            else if s starts with "Fwd: " then
                set s to text 6 thru -1 of s
                set changed to true
            else if s starts with "Re:" then
                set s to text 4 thru -1 of s
                set changed to true
            else if s starts with "Fwd:" then
                set s to text 5 thru -1 of s
                set changed to true
            else if s starts with "AW: " then
                set s to text 5 thru -1 of s
                set changed to true
            else if s starts with "WG: " then
                set s to text 5 thru -1 of s
                set changed to true
            end if
        end repeat
        return s
    end stripPrefixes
    """

    static func insertReply(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let lines = escaped.components(separatedBy: "\n")
        let asString = lines.joined(separator: "\" & return & \"")
        return """
        tell application "Mail"
            try
                set outMsg to outgoing message 1
                set oldContent to content of outMsg
                set content of outMsg to "\(asString)" & return & return & oldContent
            on error errMsg
                -- Fallback: use clipboard and paste
                set the clipboard to "\(asString)"
                tell application "System Events"
                    tell process "Mail"
                        set frontmost to true
                        delay 0.2
                        keystroke "a" using command down
                        delay 0.1
                        keystroke "v" using command down
                    end tell
                end tell
            end try
        end tell
        """
    }

    static let checkMailRunning = """
    tell application "System Events"
        return (name of processes) contains "Mail"
    end tell
    """
}
