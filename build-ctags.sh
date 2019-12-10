#!/bin/bash -e
#
# Copyright 2016-2018 (c) Yousong Zhou
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Might as well just try universal-ctags or rewrite another one.  Should be fun
# trying those lexer things
#
# - https://github.com/universal-ctags/ctags
#
PKG_NAME=ctags
PKG_VERSION=5.8
PKG_SOURCE="$PKG_NAME-$PKG_VERSION.tar.gz"
PKG_SOURCE_URL="https://downloads.sourceforge.net/ctags/$PKG_SOURCE"
PKG_SOURCE_MD5SUM=c00f82ecdcc357434731913e5b48630d

. "$PWD/env.sh"

EXTRA_CFLAGS+=(-g)

do_patch() {
	cd "$PKG_SOURCE_DIR"

	apply_patch <<"EOF"
6 How to Use Variables, GNU make manual

	A variable name may be any sequence of characters not containing ‘:’,
	‘#’, ‘=’, or leading or trailing whitespace. However, variable names
	containing characters other than letters, numbers, and underscores
	should be avoided, as they may be given special meanings in the future,
	and with some shells they cannot be passed through the environment to a
	sub-make

Allow '/' to be valid lexcial element of identifier

The ungetc() is needed for the following case when c is "M" after reading
"override"

	override MAKE:=123

Index: ctags-5.8/make.c
===================================================================
--- ctags-5.8.orig/make.c
+++ ctags-5.8/make.c
@@ -70,17 +70,19 @@ static int skipToNonWhite (void)
 
 static boolean isIdentifier (int c)
 {
-	return (boolean)(c != '\0' && (isalnum (c)  ||  strchr (".-_", c) != NULL));
+	return (boolean)(c != '\0' && (isalnum (c)  ||  strchr (".-_/", c) != NULL));
 }
 
-static void readIdentifier (const int first, vString *const id)
+static void readIdentifier (const int first, vString *const id, int in_define)
 {
 	int c = first;
 	vStringClear (id);
-	while (isIdentifier (c))
+	while (isIdentifier (c) || (in_define && c != '\0' && strchr("$(, )", c) != NULL))
 	{
 		vStringPut (id, c);
 		c = nextChar ();
+		if (!strcmp (vStringValue (id), "define") && c == ' ')
+			break;
 	}
 	fileUngetc (c);
 	vStringTerminate (id);
@@ -112,9 +114,9 @@ static void findMakeTags (void)
 {
 	vString *name = vStringNew ();
 	boolean newline = TRUE;
-	boolean in_define = FALSE;
 	boolean in_rule = FALSE;
 	boolean variable_possible = TRUE;
+	int in_define = 0;
 	int c;
 
 	while ((c = nextChar ()) != EOF)
@@ -151,26 +153,24 @@ static void findMakeTags (void)
 		}
 		else if (variable_possible && isIdentifier (c))
 		{
-			readIdentifier (c, name);
+			readIdentifier (c, name, in_define);
 			if (strcmp (vStringValue (name), "endef") == 0)
-				in_define = FALSE;
-			else if (in_define)
-				skipLine ();
+				in_define -= 1;
 			else if (strcmp (vStringValue (name), "define") == 0  &&
 				isIdentifier (c))
 			{
-				in_define = TRUE;
+				in_define += 1;
 				c = skipToNonWhite ();
-				readIdentifier (c, name);
+				readIdentifier (c, name, in_define);
 				makeSimpleTag (name, MakeKinds, K_MACRO);
 				skipLine ();
 			}
-			else {
+			else if (!in_define) {
 				if (strcmp(vStringValue (name), "export") == 0 &&
 					isIdentifier (c))
 				{
 					c = skipToNonWhite ();
-					readIdentifier (c, name);
+					readIdentifier (c, name, in_define);
 				}
 				c = skipToNonWhite ();
 				if (strchr (":?+", c) != NULL)
@@ -193,6 +193,8 @@ static void findMakeTags (void)
 					in_rule = FALSE;
 					skipLine ();
 				}
+				else
+					fileUngetc (c);
 			}
 		}
 		else
EOF

	apply_patch <<"EOF"
According to "2. Shell Command Language", IEEE Std 1003.1, 2004 Edition

	2.9.5 Function Definition Command

	A function is a user-defined name that is used as a simple command to call
	a compound command with new positional parameters. A function is defined with a
	"function definition command".

	The format of a function definition command is as follows:

		fname() compound-command[io-redirect ...]

	The function is named fname; the application shall ensure that it is a name
	(see the Base Definitions volume of IEEE Std 1003.1-2001, Section 3.230,
	Name).  An implementation may allow other characters in a function name as an
	extension. The implementation shall maintain separate name spaces for functions
	and variables.

Colon character is allowed by bash in function names though the bash manual says
in its DEFINITIONS section

	name   A word consisting only of alphanumeric characters and underscores, and
	beginning with an alphabetic character or an underscore.  Also referred to as
	an identifier.

k8s also uses dash character in shell function names

--- a/sh.c.orig	2017-08-16 14:45:39.781096557 +0800
+++ b/sh.c	2017-08-16 14:46:16.313107991 +0800
@@ -75,9 +75,9 @@ static void findShTags (void)
 			while (isspace ((int) *cp))
 				++cp;
 		}
-		if (! (isalnum ((int) *cp) || *cp == '_'))
+		if (! (isalnum ((int) *cp) || *cp == '_' || *cp == ':' || *cp == '-'))
 			continue;
-		while (isalnum ((int) *cp)  ||  *cp == '_')
+		while (isalnum ((int) *cp)  ||  *cp == '_' || *cp == ':' || *cp == '-')
 		{
 			vStringPut (name, (int) *cp);
 			++cp;
EOF

	apply_patch <<"EOF"
--- a/Makefile.in.orig	2016-06-01 20:09:20.911155981 +0800
+++ b/Makefile.in	2016-06-01 20:09:29.703156974 +0800
@@ -24,7 +24,7 @@
 libdir	= @libdir@
 incdir	= @includedir@
 mandir	= @mandir@
-SLINK	= @LN_S@
+SLINK	= @LN_S@ -f
 STRIP	= @STRIP@
 CC	= @CC@
 DEFS	= @DEFS@
@@ -85,12 +85,12 @@ EMAN	= $(ETAGS_PROG).$(manext)
 #
 CTAGS_EXEC	= $(CTAGS_PROG)$(EXEEXT)
 ETAGS_EXEC	= $(ETAGS_PROG)$(EXEEXT)
-DEST_CTAGS	= $(bindir)/$(CTAGS_EXEC)
-DEST_ETAGS	= $(bindir)/$(ETAGS_EXEC)
-DEST_READ_LIB	= $(libdir)/$(READ_LIB)
-DEST_READ_INC	= $(incdir)/$(READ_INC)
-DEST_CMAN	= $(man1dir)/$(CMAN)
-DEST_EMAN	= $(man1dir)/$(EMAN)
+DEST_CTAGS	= $(DESTDIR)$(bindir)/$(CTAGS_EXEC)
+DEST_ETAGS	= $(DESTDIR)$(bindir)/$(ETAGS_EXEC)
+DEST_READ_LIB	= $(DESTDIR)$(libdir)/$(READ_LIB)
+DEST_READ_INC	= $(DESTDIR)$(incdir)/$(READ_INC)
+DEST_CMAN	= $(DESTDIR)$(man1dir)/$(CMAN)
+DEST_EMAN	= $(DESTDIR)$(man1dir)/$(EMAN)
 
 #
 # primary rules
@@ -139,7 +139,9 @@ install-ebin: $(DEST_ETAGS)
 install-lib: $(DEST_READ_LIB) $(DEST_READ_INC)
 
 $(DEST_CTAGS): $(CTAGS_EXEC) $(bindir) FORCE
+	mkdir -p "`dirname $@`"
 	$(INSTALL_PROG) $(CTAGS_EXEC) $@  &&  chmod 755 $@
+	cd $(bindir) && $(SLINK) $(CTAGS_EXEC) $(CTAGS_PROG)-exuberant
 
 $(DEST_ETAGS):
 	- if [ -x $(DEST_CTAGS) ]; then \
@@ -154,6 +155,7 @@ install-cman: $(DEST_CMAN)
 install-eman: $(DEST_EMAN)
 
 $(DEST_CMAN): $(man1dir) $(MANPAGE) FORCE
+	- mkdir -p "`dirname $@`"
 	- $(INSTALL_DATA) $(srcdir)/$(MANPAGE) $@  &&  chmod 644 $@
 
 $(DEST_EMAN):
@@ -165,9 +167,11 @@ $(DEST_EMAN):
 # install the library
 #
 $(DEST_READ_LIB): $(READ_LIB) $(libdir) FORCE
+	- mkdir -p "`dirname $@`"
 	$(INSTALL_PROG) $(READ_LIB) $@  &&  chmod 644 $@
 
 $(DEST_READ_INC): $(READ_INC) $(incdir) FORCE
+	- mkdir -p "`dirname $@`"
 	$(INSTALL_PROG) $(READ_INC) $@  &&  chmod 644 $@
 
 
EOF
}
