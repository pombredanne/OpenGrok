/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").  
 * You may not use this file except in compliance with the License.
 *
 * See LICENSE.txt included in this distribution for the specific
 * language governing permissions and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at LICENSE.txt.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2005, 2010, Oracle and/or its affiliates. All rights reserved.
 */

/**
 * for plain text tokenizers
 */
package org.opensolaris.opengrok.search.context;

import java.io.CharArrayReader;
import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
import java.util.List;
import java.util.TreeMap;
import org.opensolaris.opengrok.search.Hit;
import org.opensolaris.opengrok.web.Util;
%%

%public
%class PlainLineTokenizer
%line
%unicode
%type String 
%ignorecase
%switch
%char

%{
  /**
   * Buffer that holds all the text from the start of the current line, or,
   * in the case of a match that spans multiple lines, from the start of the
   * first line part of the matching region.
   */
  private final StringBuilder markedContents = new StringBuilder();
  int markedPos=0;
  int curLinePos=0;
  int matchStart=-1;
  int markedLine=0;
  int rest=0;
  boolean wait = false;
  boolean dumpRest = false;
  Writer out;
  String url;
  TreeMap<Integer, String[]> tags;
  boolean prevHi = false;
  Integer prevLn = null;
  List<Hit> hits;
  Hit hit;
  StringBuilder sb;
  boolean alt;

  /**
   * Set the writer that should receive all output
   * @param out The new writer to write to
   */
  public void setWriter(Writer out) {
        yyline = 1;
        this.out = out;
  }

  /**
   * Set the name of the file we are working on (needed if we would like to
   * generate a list of hits instead of generating html)
   * @param filename the name of the file
   */
  public void setFilename(String filename) {
     this.url = filename;
     hit = new Hit(filename, null, null, false, alt);
  }
  
  /**
   * Set the list we should create Hit objects for
   * @param hits the hits we should add Hit objects
   */
  public void setHitList(List<Hit> hits) {
     this.hits = hits;
  }

    public void setAlt(boolean alt) {
        this.alt = alt;
    }


  public void reInit(char[] buf, int len, Writer out, String url, TreeMap<Integer, String[]> tags) {
        reInit(new CharArrayReader(buf, 0, len), out, url, tags);
  }

  public void reInit(Reader in, Writer out, String url, TreeMap<Integer, String[]> tags) {
        yyreset(in);

        markedContents.setLength(0);
        wait = false;
        dumpRest = false;
        rest = 0;
        markedPos=0;
        curLinePos=0;
        matchStart=-1;
        markedLine=0;
        yyline = 1;
        this.out = out;
        this.url = url;
        this.tags = tags;
        if(this.tags == null) {
                this.tags = new TreeMap<Integer, String[]>();
        }
        prevHi = false;
  }

  /** Current token could be part of a match. Hold on... */
  public void holdOn() {
     if(!wait) {
        wait = true;
        matchStart = markedContents.length() - yylength();
     }
  }

  /** Not a match after all. */
  public void neverMind() {
        wait = false;
        if(!dumpRest) {
                markedPos = curLinePos;
                markedLine = yyline;
        }
        matchStart = -1;
  }

  
  private int printWithNum(int start, int end, int lineNo,
                           boolean bold) throws IOException {
        if (bold) {
            out.write("<em>");
        }

        for(int i=start;i<end; i++) {
                char ch = markedContents.charAt(i);
                switch(ch) {
                case '\n':
                        ++lineNo;
                        Integer ln = Integer.valueOf(lineNo);
                        boolean hi = tags.containsKey(ln);

                        if (bold) {
                            out.write("</em>");
                        }

                        out.write("</a>");
                        if(prevHi){
                                out.write(" <i> ");
                                String[] desc = tags.remove(prevLn);
                                out.write(desc[2]);
                                out.write(" </i>");
                        }
                        out.write("<br/>");

                        prevHi = hi;
                        prevLn = ln;
                        if(hi) out.write("<span class=\"h\">");
                        out.write("<a class=\"s\" href=\"");
                        out.write(url);
                        String num = String.valueOf(lineNo);
                        out.write(num);
                        out.write("\"><span class=\"l\">");
                        out.write(num);
                        out.write("</span> ");
                        if (bold) {
                            out.write("<em>");
                        }
                        break;
                case '<':
                        out.write("&lt;");
                        break;
                case '>':
                        out.write("&gt;");
                        break;
                case '&':
                        out.write("&amp;");
                        break;
                default:
                        out.write(ch);
                }
        }

        if (bold) {
            out.write("</em>");
        }

        return lineNo;
  }

  private int formatWithNum(int start, int end, int lineNo) {
        for(int i=start;i<end; i++) {
                char ch = markedContents.charAt(i);
                switch(ch) {
                case '\n':
                        ++lineNo;
                        Integer ln = Integer.valueOf(lineNo);
                        boolean hi = tags.containsKey(ln);
                        if(prevHi){
                           String[] desc = tags.remove(prevLn);
                           hit.setTag(desc[2]);
                        }
                        prevHi = hi;
                        prevLn = ln;
                        sb.append(' ');
                        break;
                case '<':
                        sb.append("&lt;");
                        break;
                case '>':
                        sb.append("&gt;");
                        break;
                case '&':
                        sb.append("&amp;");
                        break;
                default:
                        sb.append(ch);
                }
        }
        return lineNo;
  }


  public void printContext() throws IOException {
        if (sb == null) {
            sb = new StringBuilder();
        }

        if (hit == null) {
           hit = new Hit(url, null, null, false, alt);
        }

        wait = false;
        if (matchStart == -1) {
                matchStart = markedContents.length() - yylength();
        }

        if(curLinePos == markedPos) {
                        Integer ln = Integer.valueOf(markedLine);
                        prevHi = tags.containsKey(ln);
                        prevLn = ln;
                        if (prevHi) {
                                prevLn = ln;
                        }

                        if (out != null) {
                           out.write("<a class=\"s\" href=\"");
                           out.write(url);
                           String num = String.valueOf(markedLine);
                           out.write(num);
                           out.write("\"><span class=\"l\">");
                           out.write(num);
                           out.write("</span> ");
                        }
        }

        if (out != null) {
           // print first part of line without normal font
           markedLine = printWithNum(
                    markedPos, matchStart, markedLine, false);
           // use bold font for the match
           markedLine = printWithNum(
                   matchStart, markedContents.length(), markedLine, true);
        } else {
           markedLine = formatWithNum(markedPos, matchStart, markedLine);
           hit.setLineno(String.valueOf(markedLine));
           sb.append("<em>");
           markedLine = formatWithNum(
                    matchStart, markedContents.length(), markedLine);
           sb.append("</em>");
        }

        // Remove everything up to the start of the current line in the
        // buffered contents.
        markedContents.delete(0, curLinePos);
        curLinePos = 0;
        markedPos = markedContents.length();
        matchStart = -1;
        dumpRest = true;
        rest = markedPos;
  }
    public void printContext(String urlPrefix) throws IOException {
        if (sb == null) {
            sb = new StringBuilder();
        }

        if (hit == null) {
           hit = new Hit(url, null, null, false, alt);
        }

        wait = false;
        if (matchStart == -1) {
                matchStart = markedContents.length() - yylength();
        }

        if(curLinePos == markedPos) {
                        Integer ln = Integer.valueOf(markedLine);
                        prevHi = tags.containsKey(ln);
                        prevLn = ln;
                        if (prevHi) {
                                prevLn = ln;
                        }

                        if (out != null) {
                           out.write("<a class=\"s\" href=\"");
                           out.write(urlPrefix);
                           out.write(url);
                           String num = String.valueOf(markedLine);
                           out.write(num);
                           out.write("\"><span class=\"l\">");
                           out.write(num);
                           out.write("</span> ");
                        }
        }

        if (out != null) {
           // print first part of line without normal font
           markedLine = printWithNum(
                    markedPos, matchStart, markedLine, false);
           // use bold font for the match
           markedLine = printWithNum(
                   matchStart, markedContents.length(), markedLine, true);
        } else {
           markedLine = formatWithNum(markedPos, matchStart, markedLine);
           hit.setLineno(String.valueOf(markedLine));
           sb.append("<em>");
           markedLine = formatWithNum(
                    matchStart, markedContents.length(), markedLine);
           sb.append("</em>");
        }

        // Remove everything up to the start of the current line in the
        // buffered contents.
        markedContents.delete(0, curLinePos);
        curLinePos = 0;
        markedPos = markedContents.length();
        matchStart = -1;
        dumpRest = true;
        rest = markedPos;
  }
  public void dumpRest() throws IOException {
        if(dumpRest) {
        final int maxLooks = 100;
        for (int i=0; ; i++) {
            final boolean endOfBuffer = (i >= markedContents.length() - rest);
            final boolean newline = !endOfBuffer && markedContents.charAt(rest+i) == '\n';
            if (endOfBuffer || newline || i >= maxLooks) {
                           if (out != null) {
                                printWithNum(rest, rest+i-1,
                                             markedLine, false);

                // Assume that this line has been truncated if we don't find
                // a newline after looking at maxLooks characters, or if we
                // reach the end of the buffer and the size of the buffer is
                // Context.MAXFILEREAD (which means that the file has probably
                // been truncated).
                if (!newline &&
                      ((i >= maxLooks) ||
                       (endOfBuffer && (yychar + yylength()) == Context.MAXFILEREAD))) {
                    out.write(" (&hellip;)");
                }

                                out.write("</a>");
                                if (prevHi) {
                                        out.write(" <i> ");
                                        String[] desc = tags.remove(prevLn);
                                        out.write(desc[2]);
                                        out.write(" </i>");
                                }
                                out.write("<br/>");
                           } else {
                               formatWithNum(rest, rest+i-1, markedLine);
                               hit.setLine(sb.toString());
                               if (prevHi) {
                                  String[] desc = tags.remove(prevLn);
                                  hit.setTag(desc[2]);
                               }
                               hits.add(hit);
                           }
                           break;
                        }
                }
        }
        if (tags.size() > 0) {
        if (out != null) {
           for(Integer rem : tags.keySet()) {
                String[] desc = tags.get(rem);
                out.write("<a class=\"s\" href=\"");
                out.write(url);
                out.write(desc[1]);
                out.write("\"><span class=\"l\">");
                out.write(desc[1]);
                out.write("</span> ");
                out.write(Util.htmlize(desc[3]).replaceAll(desc[0], "<em>" + desc[0] + "</em>"));
                out.write("</a> <i> ");
                out.write(desc[2]);
                out.write(" </i><br/>");
           }
        } else {
           for(Integer rem : tags.keySet()) {
                String[] desc = tags.get(rem);
                hit = new Hit(url, "<html>" + Util.htmlize(desc[3]).replaceAll(desc[0], "<em>" + desc[0] + "</em>"), 
                              desc[1], false, alt);
                hit.setTag(desc[2]);
                hits.add(hit);
           }
        }
        }
  }
%}

//WhiteSpace     = [ \t\f\r]+|\n
Identifier = [a-zA-Z_] [a-zA-Z0-9_]*
Number = [0-9]+|[0-9]+\.[0-9]+| "0[xX]" [0-9a-fA-F]+
Printable = [\@\$\%\^\&\-+=\?\.\:]


%%
{Identifier}|{Number}|{Printable}    {
    String text = yytext();
    markedContents.append(text);
    return text;
}
<<EOF>>   { return null;}

\n      {
                markedContents.append(yycharat(0));
                if(!wait) {
                        markedPos = markedContents.length();
                        markedLine = yyline+1;
                        matchStart = -1;
                        curLinePos = markedPos;
                }
                if(dumpRest) {
                        int endPos = markedContents.length() - yylength();
                        if (out != null) {
                           printWithNum(rest, endPos, markedLine, false);
                           out.write("</a>");
                           if(prevHi){
                                out.write(" <i> ");
                                String[] desc = tags.remove(prevLn);
                                out.write(desc[2]);
                                out.write("</i> ");
                           }
                           out.write("<br/>");
                        } else {
                           formatWithNum(rest, endPos, markedLine);
                           hit.setLine(sb.toString());
                           if(prevHi){
                                String[] desc = tags.remove(prevLn);
                                hit.setTag(desc[2]);
                           }
                           hits.add(hit);
                           sb.setLength(0);
                           hit = new Hit(url, null, null, false, alt);
                     }
                        dumpRest = false;

                }
                if (!wait) {
                    // We have dumped the rest of the line, begun a new line,
                    // and we're not inside a possible match, so it's safe to
                    // forget the buffered contents.
                    markedContents.setLength(0);
                    markedPos = 0;
                    curLinePos = 0;
                }
        }

.       { markedContents.append(yycharat(0)); }
