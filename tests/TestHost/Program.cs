using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using SendNotes;

namespace SendNotesTests
{
    /// <summary>
    /// Test host for the Send Notes plugin code, run on project folders (Settings.xml + Notes_*.xml):
    ///   TestHost list SRC BOOK CH [resolved]          the notes of one chapter
    ///   TestHost send SRC DST BOOK CH NOTE[:n]...     sends notes of that chapter (NOTE = thread id or "all";
    ///                                                 n = 1-based comment, default = the last that can be sent)
    ///   TestHost form SRC DST... [--lang L] [--ref BOOK CH [V]]
    /// SN_MOVE="BOOK CH [V]" (form) acts as if Paratext moved there 2 seconds after the window opens.
    /// SN_REOPENFILE (form): when that file appears, it holds "PROJECT BOOK CH [V]" (see below).
    /// </summary>
    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.Error.WriteLine("usage: TestHost list|send|form SRC ...");
                return 2;
            }
            // A WinExe has no console to set an encoding on: write UTF-8 to whatever stdout is.
            var stdout = new StreamWriter(Console.OpenStandardOutput(), new UTF8Encoding(false));
            stdout.AutoFlush = true;
            Console.SetOut(stdout);
            var source = new FolderNoteProject(args[1]);
            switch (args[0])
            {
                case "list":
                {
                    int book = FolderNoteProject.BookNumber(args[2]);
                    bool resolved = args.Length > 4 && args[4] == "resolved";
                    foreach (NoteThread t in source.GetNotes(book, int.Parse(args[3]), resolved))
                        Print(t);
                    return 0;
                }
                case "send":
                {
                    var target = new FolderNoteProject(args[2]);
                    int book = FolderNoteProject.BookNumber(args[3]);
                    IList<NoteThread> notes = source.GetNotes(book, int.Parse(args[4]), false);
                    var items = new List<SendItem>();
                    foreach (string spec in args.Skip(5))
                    {
                        string[] parts = spec.Split(':');
                        foreach (NoteThread t in notes.Where(n => parts[0] == "all" || n.Key == parts[0]))
                        {
                            int c = parts.Length > 1 ? int.Parse(parts[1]) - 1 : SentMarker.DefaultComment(t);
                            if (c >= 0) items.Add(new SendItem { Thread = t, Comment = t.Comments[c] });
                        }
                    }
                    Strings s = Strings.For(Environment.GetEnvironmentVariable("SN_LANG"));
                    SendReport r = SendRunner.Run(source, target, items, s, new DateTime(2026, 11, 3));
                    Console.WriteLine("ITEMS " + items.Count);
                    Console.WriteLine(SendRunner.Describe(r, source, target, s));
                    Console.WriteLine("NOTARGETLOCK " + r.NoTargetLock + " NOSOURCELOCK " + r.NoSourceLock);
                    return 0;
                }
                case "form":
                {
                    var projects = new List<FolderNoteProject> { source };
                    string lang = null;
                    int refBook = 0, refChapter = 0, refVerse = 0;
                    for (int i = 2; i < args.Length; i++)
                    {
                        if (args[i] == "--lang") lang = args[++i];
                        else if (args[i] == "--ref")
                        {
                            refBook = FolderNoteProject.BookNumber(args[++i]);
                            refChapter = int.Parse(args[++i]);
                            int v;
                            if (i + 1 < args.Length && int.TryParse(args[i + 1], out v)) { refVerse = v; i++; }
                        }
                        else projects.Add(new FolderNoteProject(args[i]));
                    }
                    var host = new FolderNoteHost(projects, source, refBook, refChapter, refVerse);
                    Application.EnableVisualStyles();
                    var form = new SendNotesForm(host, Strings.For(lang));
                    string move = Environment.GetEnvironmentVariable("SN_MOVE");
                    if (!string.IsNullOrEmpty(move))
                    {
                        string[] m = move.Split(' ');
                        var timer = new Timer { Interval = 2000 };
                        timer.Tick += delegate
                        {
                            timer.Stop();
                            host.Move(FolderNoteProject.BookNumber(m[0]), int.Parse(m[1]), m.Length > 2 ? int.Parse(m[2]) : 1);
                        };
                        form.Shown += delegate { timer.Start(); };
                    }
                    // SN_REOPENFILE: when that file appears, it holds "PROJECT BOOK CH" and the host acts
                    // as if the menu command was chosen again in that project's window there.
                    string reopen = Environment.GetEnvironmentVariable("SN_REOPENFILE");
                    if (!string.IsNullOrEmpty(reopen))
                    {
                        var poll = new Timer { Interval = 300 };
                        poll.Tick += delegate
                        {
                            if (!File.Exists(reopen)) return;
                            string[] m;
                            try
                            {
                                m = File.ReadAllText(reopen).Trim().Split(' ');
                                File.Delete(reopen);
                            }
                            catch (IOException)
                            {
                                return;   // still being written
                            }
                            FolderNoteProject p = projects.FirstOrDefault(x => x.ShortName == m[0]);
                            form.RefreshFromParatext(p != null ? p.Id : null, FolderNoteProject.BookNumber(m[1]), int.Parse(m[2]),
                                m.Length > 3 ? int.Parse(m[3]) : 1);
                        };
                        form.Shown += delegate { poll.Start(); };
                    }
                    // So the UI test can check that Go to asks Paratext to go to the verse.
                    form.FormClosed += delegate
                    {
                        Console.WriteLine("GOTO " + string.Join(", ", projects.SelectMany(p => p.GoTos).ToArray()));
                    };
                    Application.Run(form);
                    return 0;
                }
            }
            Console.Error.WriteLine("unknown mode " + args[0]);
            return 2;
        }

        private static void Print(NoteThread t)
        {
            int d = SentMarker.DefaultComment(t);
            string sent = string.Join(";", SentMarker.SentTo(t).Select(kv => kv.Key + " " + kv.Value).ToArray());
            Console.WriteLine(string.Join("\t", new[] {
                t.Key, t.Reference, t.IsResolved ? "resolved" : "open", t.Comments.Count.ToString(),
                (d + 1).ToString(), sent, d >= 0 ? t.Comments[d].Text.Replace("\n", " / ") : "-" }));
        }
    }
}
