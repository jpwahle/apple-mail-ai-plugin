import Foundation

enum MailScripts {
    /// Read context from the currently open compose window in Mail.
    ///
    /// Implemented entirely against the Mail scripting dictionary — no System
    /// Events / Accessibility calls — so the app only needs Automation
    /// permission for Mail, nothing else.
    ///
    /// Detection priority:
    ///   1. `outgoing message 1` properties (best: gives recipients + draft)
    ///   2. Any Mail `window` that is not the `message viewer`'s window (the
    ///      list/reading pane). This covers the macOS Sonoma/Sequoia case
    ///      where a brand-new blank compose window doesn't show up in
    ///      `outgoing messages`.
    static let fetchComposerContext = """
    set composeSubject to ""
    set recipientList to ""
    set draftContent to ""
    set composeWinL to "-"
    set composeWinT to "-"
    set composeWinR to "-"
    set composeWinB to "-"
    set hasComposer to false
    set debugInfo to ""

    tell application "Mail"
        -- Pass 1: outgoing message. Populates everything.
        try
            set outMsgCount to count of outgoing messages
            set debugInfo to "out:" & outMsgCount
            if outMsgCount > 0 then
                set outMsg to outgoing message 1
                try
                    set composeSubject to subject of outMsg
                end try
                try
                    repeat with r in to recipients of outMsg
                        if recipientList is not "" then set recipientList to recipientList & ", "
                        set recipientList to recipientList & (address of r)
                    end repeat
                end try
                try
                    set draftContent to content of outMsg
                end try
                set hasComposer to true
            end if
        on error errMsg
            set debugInfo to debugInfo & " outErr:" & errMsg
        end try

        -- Pass 2: find a non-viewer window. Works even for blank new
        -- compose windows that aren't exposed via `outgoing messages`.
        try
            set viewerNames to {}
            set viewerCount to count of message viewers
            set debugInfo to debugInfo & " vCount:" & viewerCount
            repeat with mv in message viewers
                try
                    set n to name of (window of mv)
                    set viewerNames to viewerNames & {n}
                end try
            end repeat

            set winCount to count of windows
            repeat with i from 1 to winCount
                try
                    set w to window i
                    set wName to name of w
                    set isViewer to false
                    repeat with vn in viewerNames
                        if wName is equal to (vn as string) then
                            set isViewer to true
                            exit repeat
                        end if
                    end repeat
                    if not isViewer then
                        -- Non-viewer window in Mail == compose (or reading)
                        -- window. Both are fine for our purposes.
                        if not hasComposer then
                            set composeSubject to wName
                            set hasComposer to true
                        end if
                        try
                            set b to bounds of w
                            set composeWinL to (item 1 of b) as string
                            set composeWinT to (item 2 of b) as string
                            set composeWinR to (item 3 of b) as string
                            set composeWinB to (item 4 of b) as string
                        end try
                        exit repeat
                    end if
                end try
            end repeat
        on error errMsg
            set debugInfo to debugInfo & " winErr:" & errMsg
        end try
    end tell

    if not hasComposer then
        return "ERROR:NO_COMPOSER|" & debugInfo
    end if

    -- Reply detection
    set isReply to false
    if composeSubject starts with "Re: " then set isReply to true
    if composeSubject starts with "Re:" then set isReply to true
    if composeSubject starts with "RE: " then set isReply to true
    if composeSubject starts with "RE:" then set isReply to true
    if composeSubject starts with "Fwd: " then set isReply to true
    if composeSubject starts with "Fwd:" then set isReply to true
    if composeSubject starts with "FWD: " then set isReply to true
    if composeSubject starts with "FWD:" then set isReply to true
    if composeSubject starts with "AW: " then set isReply to true
    if composeSubject starts with "AW:" then set isReply to true
    if composeSubject starts with "WG: " then set isReply to true
    if composeSubject starts with "WG:" then set isReply to true

    set output to "COMPOSER" & linefeed
    set output to output & "SUBJECT:" & composeSubject & linefeed
    set output to output & "TO:" & recipientList & linefeed
    set output to output & "FRAME:" & composeWinL & "," & composeWinT & "," & composeWinR & "," & composeWinB & linefeed
    set output to output & "DRAFT_START" & linefeed
    set output to output & draftContent & linefeed
    set output to output & "DRAFT_END" & linefeed
    set output to output & "---END_COMPOSER---" & linefeed

    if not isReply then
        return output
    end if

    set baseSubject to composeSubject
    set changed to true
    repeat while changed
        set changed to false
        if baseSubject starts with "Re: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "Re:" then
            set baseSubject to text 4 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "RE: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "Fwd: " then
            set baseSubject to text 6 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "Fwd:" then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "AW: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "WG: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        end if
    end repeat

    if baseSubject is "" then
        return output
    end if

    tell application "Mail"
        set threadMsgs to {}
        try
            repeat with acct in accounts
                repeat with mbName in {"INBOX", "Sent Messages", "Sent", "Gesendet", "Archive", "Archiv", "All Mail"}
                    try
                        set mb to mailbox mbName of acct
                        set matches to (every message of mb whose subject contains baseSubject)
                        set threadMsgs to threadMsgs & matches
                    end try
                end repeat
            end repeat
        end try

        set msgCount to count of threadMsgs
        if msgCount > 20 then
            set threadMsgs to items (msgCount - 19) thru msgCount of threadMsgs
        end if

        repeat with msg in threadMsgs
            set output to output & "FROM:" & (sender of msg) & linefeed
            try
                set rList to ""
                repeat with r in to recipients of msg
                    if rList is not "" then set rList to rList & ", "
                    set rList to rList & (address of r)
                end repeat
                set output to output & "TO:" & rList & linefeed
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
    end tell
    return output
    """

    /// Write the generated reply into the current compose window.
    /// Mail-scripting-only path: set `content of outgoing message 1`. If that
    /// fails (no outgoing message visible to the API), fall back to placing
    /// the text on the clipboard + activating Mail so the user can paste.
    static func insertReply(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let lines = escaped.components(separatedBy: "\n")
        let asString = lines.joined(separator: "\" & return & \"")
        return """
        set insertedViaAPI to false
        tell application "Mail"
            try
                if (count of outgoing messages) > 0 then
                    set outMsg to outgoing message 1
                    set oldContent to ""
                    try
                        set oldContent to content of outMsg
                    end try
                    set content of outMsg to "\(asString)" & return & return & oldContent
                    set insertedViaAPI to true
                end if
            on error errMsg
                -- fall through
            end try
            activate
        end tell

        if not insertedViaAPI then
            set the clipboard to "\(asString)"
        end if
        return "OK"
        """
    }

    static let checkMailRunning = """
    tell application "System Events"
        return (name of processes) contains "Mail"
    end tell
    """
}
