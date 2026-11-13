# Send Notes to Project

*This page is the English user guide, [SendNotes_UserGuide.rtf](plugin/SendNotes_UserGuide.rtf). The guide is also available in Spanish ([SendNotes_UserGuide_sp.rtf](plugin/SendNotes_UserGuide_sp.rtf)) and French ([SendNotes_UserGuide_fr.rtf](plugin/SendNotes_UserGuide_fr.rtf)).*

## Purpose

Send Notes to Project is a Paratext plugin for consultants. Consultants often write their notes in a consultant notes project (for example PLe11). When a note is ready, this tool sends the comment you choose to the project itself (for example PDT15), as a new note at the same verse, without typing it again.

Each note can be a string of several comments. You choose which comment to send; the last one is chosen at first.

The tool reads one chapter at a time.

## Installing

1. Download Install_Phils_tools.exe from the Paratext_Plugins folder. If your browser warns about the file, choose to keep it.

2. Close Paratext.

3. Double-click Install_Phils_tools.exe. If Windows says it protected your PC, click "More info", then "Run anyway" (the installer is not signed yet).

4. Tick Send Notes to Project and click "Install / update ticked". It installs into every Paratext 9 on the computer. If Windows asks for permission, click Yes. The same window updates the plugin later (its status then says "Update available") or removes it ("Remove ticked"), and its "User guide" button opens this guide.

## How to use

1. Open the project that will receive the notes (for example PDT15) and choose Tools > Send Notes to Project... The tool cannot be started from the consultant notes project itself. The window opens at the book and chapter you are looking at.

2. In "From", choose the consultant notes project the notes come from. The list offers every consultant notes project on the computer.

3. In "Send to", choose the project that should receive the notes. Only projects you may add notes to are listed (you are not an observer there). Your choice is remembered for that consultant notes project and stays the default until you choose another project.

4. Choose the book and chapter, or use "< Previous" and "Next >". With "Follow Paratext" ticked, the window moves to the chapter you go to in Paratext.

To see the notes of a single verse instead of the whole chapter, tick "Only verse" and choose the verse. "< Previous" and "Next >" then move one verse at a time, and "Follow Paratext" follows the verse. A note on a range of verses (for example ACT 1:4-6) is listed at each of its verses. The tool remembers this choice.

5. The list shows the notes of that chapter: the reference, the comment that will be sent, the number of comments, and where the note was already sent.

6. Click a note to see all its comments below the list. Click the comment you want to send; "Will be sent" shows exactly what the new note will say. A "Sent to ..." comment cannot be sent.

7. Tick the notes to send ("Tick all" ticks every note that has text), then click "Send ticked notes" and answer Yes.

"Go to in Paratext" (or a double-click on a note) shows the verse in the receiving project.

The window can stay open while you work in Paratext. To see notes added or changed since, choose Tools > Send Notes to Project... again: the list is read again, the notes you ticked stay ticked, and with "Follow Paratext" ticked the window moves to the chapter you are in.

## What happens when you send

- Each comment sent becomes a new note in the receiving project, at the same verse (mapped to that project's versification), under your name. A note on a range of verses (for example ACT 1:13-14) keeps the same range. Bold and italic are kept.
- When the note in the consultant notes project is attached to some words and the receiving project has those words in that verse, the new note is attached to the same words. Otherwise it is attached to the verse.
- "Sent to PDT15 on 2026-11-03." is added as a new comment to the note in the consultant notes project. The note stays open.
- With "Hide notes already sent to this project" ticked, notes already sent to the chosen project are hidden. If you send a note again, the tool asks first.
- If you cannot add notes to the receiving project (for example because you are an observer there), nothing is sent and the Results box says so.
- Resolved notes are not shown unless "Include resolved notes" is ticked.

The notes go through Paratext itself, so they are shared by Send/Receive like any other note.
