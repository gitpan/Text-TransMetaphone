#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <assert.h>

#include "metaphone_util.h"

#define KEY_LIMIT 4


int
IsVowel(metastring * s, int pos)
{
    char c;

    if ((pos < 0) || (pos >= s->length))
	return 0;

    c = *(s->str + pos);
    if ((c == 'A') || (c == 'E') || (c == 'I') || (c =='O') || 
        (c =='U')  || (c == 'Y'))
	return 1;

    return 0;
}


int
SlavoGermanic(metastring * s)
{
    if ((char *) strstr(s->str, "W"))
	return 1;
    else if ((char *) strstr(s->str, "K"))
	return 1;
    else if ((char *) strstr(s->str, "CZ"))
	return 1;
    else if ((char *) strstr(s->str, "WITZ"))
	return 1;
    else
	return 0;
}


void
TransMetaphone_en_US(char *str, unsigned char **codes)
{
    int        length;
    metastring *original;
    metastring *primary;
    metastring *secondary;
    int        current;
    int        last;

    current = 0;
    /* we need the real length and last prior to padding */
    length  = strlen(str); 
    last    = length - 1; 
    original = NewMetaString(str);
    /* Pad original so we can index beyond end */
    MetaphAdd(original, "     ");

    primary = NewMetaString("");
    secondary = NewMetaString("");
    primary->free_string_on_destroy = 0;
    secondary->free_string_on_destroy = 0;

    MakeUpper(original);

    /* skip these when at start of word */
    if (StringAt(original, 0, 2, "GN", "KN", "PN", "WR", "PS", ""))
	current += 1;

    /* Initial 'X' is pronounced 'Z' e.g. 'Xavier' */
    if (GetAt(original, 0) == 'X')
      {
	  MetaphAdd(primary, "s");	/* 'Z' maps to 'S' */
	  MetaphAdd(secondary, "s");
	  current += 1;
      }

    /* main loop */
    while ((primary->length < KEY_LIMIT) || (secondary->length < KEY_LIMIT))  
      {
	  if (current >= length)
	      break;

	  switch (GetAt(original, current))
	    {
	    case 'A':
	    case 'E':
	    case 'I':
	    case 'O':
	    case 'U':
	    case 'Y':
		if (current == 0)
                  {
		    /* all init vowels now map to 'A' */
		    MetaphAdd(primary, "a");
		    MetaphAdd(secondary, "a");
                  }
		current += 1;
		break;

	    case 'B':

		/* "-mb", e.g", "dumb", already skipped over... */
		MetaphAdd(primary, "p");
		MetaphAdd(secondary, "p");

		if (GetAt(original, current + 1) == 'B')
		    current += 2;
		else
		    current += 1;
		break;

	    case 0xc7: /* Ç */
		MetaphAdd(primary, "s");
		MetaphAdd(secondary, "s");
		current += 1;
		break;

	    case 'C':
		/* various germanic */
		if ((current > 1)
		    && !IsVowel(original, current - 2)
		    && StringAt(original, (current - 1), 3, "ACH", "")
		    && ((GetAt(original, current + 2) != 'I')
			&& ((GetAt(original, current + 2) != 'E')
			    || StringAt(original, (current - 2), 6, "BACHER",
					"MACHER", ""))))
		  {
		      MetaphAdd(primary, "k");
		      MetaphAdd(secondary, "k");
		      current += 2;
		      break;
		  }

		/* special case 'caesar' */
		if ((current == 0)
		    && StringAt(original, current, 6, "CAESAR", ""))
		  {
		      MetaphAdd(primary, "s");
		      MetaphAdd(secondary, "s");
		      current += 2;
		      break;
		  }

		/* italian 'chianti' */
		if (StringAt(original, current, 4, "CHIA", ""))
		  {
		      MetaphAdd(primary, "k");
		      MetaphAdd(secondary, "k");
		      current += 2;
		      break;
		  }

		if (StringAt(original, current, 2, "CH", ""))
		  {
		      /* find 'michael' */
		      if ((current > 0)
			  && StringAt(original, current, 4, "CHAE", ""))
			{
			    MetaphAdd(primary, "k");
			    MetaphAdd(secondary, "ʃ");
			    current += 2;
			    break;
			}

		      /* greek roots e.g. 'chemistry', 'chorus' */
		      if ((current == 0)
			  && (StringAt(original, (current + 1), 5, "HARAC", "HARIS", "")
			   || StringAt(original, (current + 1), 3, "HOR",
				       "HYM", "HIA", "HEM", ""))
			  && !StringAt(original, 0, 5, "CHORE", ""))
			{
			    MetaphAdd(primary, "k");
			    MetaphAdd(secondary, "k");
			    current += 2;
			    break;
			}

		      /* germanic, greek, or otherwise 'ch' for 'kh' sound */
		      if (
			  (StringAt(original, 0, 4, "VAN ", "VON ", "")
			   || StringAt(original, 0, 3, "SCH", ""))
			  /*  'architect but not 'arch', 'orchestra', 'orchid' */
			  || StringAt(original, (current - 2), 6, "ORCHES",
				      "ARCHIT", "ORCHID", "")
			  || StringAt(original, (current + 2), 1, "T", "S",
				      "")
			  || ((StringAt(original, (current - 1), 1, "A", "O", "U", "E", "") 
                          || (current == 0))
			   /* e.g., 'wachtler', 'wechsler', but not 'tichner' */
			  && StringAt(original, (current + 2), 1, "L", "R",
		                      "N", "M", "B", "H", "F", "V", "W", " ", "")))
			{
			    MetaphAdd(primary, "k");
			    MetaphAdd(secondary, "k");
			}
		      else
			{
			    if (current > 0)
			      {
				  if (StringAt(original, 0, 2, "MC", ""))
				    {
					/* e.g., "McHugh" */
					MetaphAdd(primary, "k");
					MetaphAdd(secondary, "k");
				    }
				  else
				    {
					MetaphAdd(primary, "ʧ");
					MetaphAdd(secondary, "k");
				    }
			      }
			    else
			      {
				  MetaphAdd(primary, "ʃ");
				  MetaphAdd(secondary, "ʃ");
			      }
			}
		      current += 2;
		      break;
		  }
		/* e.g, 'czerny' */
		if (StringAt(original, current, 2, "CZ", "")
		    && !StringAt(original, (current - 2), 4, "WICZ", ""))
		  {
		      MetaphAdd(primary, "s");
		      MetaphAdd(secondary, "ʃ");
		      current += 2;
		      break;
		  }

		/* e.g., 'focaccia' */
		if (StringAt(original, (current + 1), 3, "CIA", ""))
		  {
		      MetaphAdd(primary, "ʃ");
		      MetaphAdd(secondary, "ʃ");
		      current += 3;
		      break;
		  }

		/* double 'C', but not if e.g. 'McClellan' */
		if (StringAt(original, current, 2, "CC", "")
		    && !((current == 1) && (GetAt(original, 0) == 'M')))
		    /* 'bellocchio' but not 'bacchus' */
		    if (StringAt(original, (current + 2), 1, "I", "E", "H", "")
			&& !StringAt(original, (current + 2), 2, "HU", ""))
		      {
			  /* 'accident', 'accede' 'succeed' */
			  if (
			      ((current == 1)
			       && (GetAt(original, current - 1) == 'A'))
			      || StringAt(original, (current - 1), 5, "UCCEE",
					  "UCCES", ""))
			    {
				MetaphAdd(primary, "ks");
				MetaphAdd(secondary, "ks");
				/* 'bacci', 'bertucci', other italian */
			    }
			  else
			    {
				MetaphAdd(primary, "ʃ");
				MetaphAdd(secondary, "ʃ");
			    }
			  current += 3;
			  break;
		      }
		    else
		      {	  /* Pierce's rule */
			  MetaphAdd(primary, "k");
			  MetaphAdd(secondary, "k");
			  current += 2;
			  break;
		      }

		if (StringAt(original, current, 2, "CK", "CG", "CQ", ""))
		  {
		      MetaphAdd(primary, "k");
		      MetaphAdd(secondary, "k");
		      current += 2;
		      break;
		  }

		if (StringAt(original, current, 2, "CI", "CE", "CY", ""))
		  {
		      /* italian vs. english */
		      if (StringAt
			  (original, current, 3, "CIO", "CIE", "CIA", ""))
			{
			    MetaphAdd(primary, "s");
			    MetaphAdd(secondary, "ʃ");
			}
		      else
			{
			    MetaphAdd(primary, "s");
			    MetaphAdd(secondary, "s");
			}
		      current += 2;
		      break;
		  }

		/* else */
		MetaphAdd(primary, "k");
		MetaphAdd(secondary, "k");

		/* name sent in 'mac caffrey', 'mac gregor */
		if (StringAt(original, (current + 1), 2, " C", " Q", " G", ""))
		    current += 3;
		else
		    if (StringAt(original, (current + 1), 1, "C", "K", "Q", "")
			&& !StringAt(original, (current + 1), 2, "CE", "CI", ""))
		    current += 2;
		else
		    current += 1;
		break;

	    case 'D':
		if (StringAt(original, current, 2, "DG", ""))
                  {
		      if (StringAt(original, (current + 2), 1, "I", "E", "Y", ""))
		        {
			    /* e.g. 'edge' */
			    MetaphAdd(primary, "ʤ");
			    MetaphAdd(secondary, "j");
			    current += 3;
			    break;
		        }
		      else
		        {
			    /* e.g. 'edgar' */
			    MetaphAdd(primary, "tk");
			    MetaphAdd(secondary, "tk");
			    current += 2;
			    break;
		        }
                  }

		if (StringAt(original, current, 2, "DT", "DD", ""))
		  {
		      MetaphAdd(primary, "t");
		      MetaphAdd(secondary, "t");
		      current += 2;
		      break;
		  }

		/* else */
		MetaphAdd(primary, "t");
		MetaphAdd(secondary, "t");
		current += 1;
		break;

	    case 'F':
		if (GetAt(original, current + 1) == 'F')
		    current += 2;
		else
		    current += 1;
		MetaphAdd(primary, "f");
		MetaphAdd(secondary, "f");
		break;

	    case 'G':
		if (GetAt(original, current + 1) == 'H')
		  {
		      if ((current > 0) && !IsVowel(original, current - 1))
			{
			    MetaphAdd(primary, "k");
			    MetaphAdd(secondary, "k");
			    current += 2;
			    break;
			}

		      if (current < 3)
			{
			    /* 'ghislane', ghiradelli */
			    if (current == 0)
			      {
				  if (GetAt(original, current + 2) == 'I')
				    {
					MetaphAdd(primary, "j");
					MetaphAdd(secondary, "j");
				    }
				  else
				    {
					MetaphAdd(primary, "k");
					MetaphAdd(secondary, "k");
				    }
				  current += 2;
				  break;
			      }
			}
		      /* Parker's rule (with some further refinements) - e.g., 'hugh' */
		      if (
			  ((current > 1)
			   && StringAt(original, (current - 2), 1, "B", "H", "D", ""))
			  /* e.g., 'bough' */
			  || ((current > 2)
			      && StringAt(original, (current - 3), 1, "B", "H", "D", ""))
			  /* e.g., 'broughton' */
			  || ((current > 3)
			      && StringAt(original, (current - 4), 1, "B", "H", "")))
			{
			    current += 2;
			    break;
			}
		      else
			{
			    /* e.g., 'laugh', 'McLaughlin', 'cough', 'gough', 'rough', 'tough' */
			    if ((current > 2)
				&& (GetAt(original, current - 1) == 'U')
				&& StringAt(original, (current - 3), 1, "C",
					    "G", "L", "R", "T", ""))
			      {
				  MetaphAdd(primary, "f");
				  MetaphAdd(secondary, "f");
			      }
			    else if ((current > 0)
				     && GetAt(original, current - 1) != 'I')
			      {


				  MetaphAdd(primary, "k");
				  MetaphAdd(secondary, "k");
			      }

			    current += 2;
			    break;
			}
		  }

		if (GetAt(original, current + 1) == 'N')
		  {
		      if ((current == 1) && IsVowel(original, 0)
			  && !SlavoGermanic(original))
			{
			    MetaphAdd(primary, "kn");
			    MetaphAdd(secondary, "n");
			}
		      else
			  /* not e.g. 'cagney' */
			  if (!StringAt(original, (current + 2), 2, "EY", "")
			      && (GetAt(original, current + 1) != 'Y')
			      && !SlavoGermanic(original))
			{
			    MetaphAdd(primary, "n");
			    MetaphAdd(secondary, "kn");
			}
		      else
                        {
			    MetaphAdd(primary, "kn");
		            MetaphAdd(secondary, "kn");
                        }
		      current += 2;
		      break;
		  }

		/* 'tagliaro' */
		if (StringAt(original, (current + 1), 2, "LI", "")
		    && !SlavoGermanic(original))
		  {
		      MetaphAdd(primary, "kl");
		      MetaphAdd(secondary, "l");
		      current += 2;
		      break;
		  }

		/* -ges-,-gep-,-gel-, -gie- at beginning */
		if ((current == 0)
		    && ((GetAt(original, current + 1) == 'Y')
			|| StringAt(original, (current + 1), 2, "ES", "EP",
				    "EB", "EL", "EY", "IB", "IL", "IN", "IE",
				    "EI", "ER", "")))
		  {
		      MetaphAdd(primary, "k");
		      MetaphAdd(secondary, "j");
		      current += 2;
		      break;
		  }

		/*  -ger-,  -gy- */
		if (
		    (StringAt(original, (current + 1), 2, "ER", "")
		     || (GetAt(original, current + 1) == 'Y'))
		    && !StringAt(original, 0, 6, "DANGER", "RANGER", "MANGER", "")
		    && !StringAt(original, (current - 1), 1, "E", "I", "")
		    && !StringAt(original, (current - 1), 3, "RGY", "OGY",
				 ""))
		  {
		      MetaphAdd(primary, "k");
		      MetaphAdd(secondary, "j");
		      current += 2;
		      break;
		  }

		/*  italian e.g, 'biaggi' */
		if (StringAt(original, (current + 1), 1, "E", "I", "Y", "")
		    || StringAt(original, (current - 1), 4, "AGGI", "OGGI", ""))
		  {
		      /* obvious germanic */
		      if (
			  (StringAt(original, 0, 4, "VAN ", "VON ", "")
			   || StringAt(original, 0, 3, "SCH", ""))
			  || StringAt(original, (current + 1), 2, "ET", ""))
			{
			    MetaphAdd(primary, "k");
			    MetaphAdd(secondary, "k");
			}
		      else
			{
			    /* always soft if french ending */
			    if (StringAt
				(original, (current + 1), 4, "IER ", ""))
			      {
				  MetaphAdd(primary, "j");
				  MetaphAdd(secondary, "j");
			      }
			    else
			      {
				  MetaphAdd(primary, "j");
				  MetaphAdd(secondary, "k");
			      }
			}
		      current += 2;
		      break;
		  }

		if (GetAt(original, current + 1) == 'G')
		    current += 2;
		else
		    current += 1;
		MetaphAdd(primary, "k");
		MetaphAdd(secondary, "k");
		break;

	    case 'H':
		/* only keep if first & before vowel or btw. 2 vowels */
		if (((current == 0) || IsVowel(original, current - 1))
		    && IsVowel(original, current + 1))
		  {
		      MetaphAdd(primary, "h");
		      MetaphAdd(secondary, "h");
		      current += 2;
		  }
		else		/* also takes care of 'HH' */
		    current += 1;
		break;

	    case 'J':
		/* obvious spanish, 'jose', 'san jacinto' */
		if (StringAt(original, current, 4, "JOSE", "")
		    || StringAt(original, 0, 4, "SAN ", ""))
		  {
		      if (((current == 0)
			   && (GetAt(original, current + 4) == ' '))
			  || StringAt(original, 0, 4, "SAN ", ""))
			{
			    MetaphAdd(primary, "h");
			    MetaphAdd(secondary, "h");
			}
		      else
			{
			    MetaphAdd(primary, "j");
			    MetaphAdd(secondary, "h");
			}
		      current += 1;
		      break;
		  }

		if ((current == 0)
		    && !StringAt(original, current, 4, "JOSE", ""))
		  {
		      MetaphAdd(primary, "ʤ");	/* Yankelovich/Jankelowicz */
		      MetaphAdd(secondary, "a");
		  }
		else
		  {
		      /* spanish pron. of e.g. 'bajador' */
		      if (IsVowel(original, current - 1)
			  && !SlavoGermanic(original)
			  && ((GetAt(original, current + 1) == 'A')
			      || (GetAt(original, current + 1) == 'O')))
			{
			    MetaphAdd(primary, "j");
			    MetaphAdd(secondary, "h");
			}
		      else
			{
			    if (current == last)
			      {
				  MetaphAdd(primary, "ʤ");
				  MetaphAdd(secondary, "");
			      }
			    else
			      {
				  if (!StringAt(original, (current + 1), 1, "L", "T",
				                "K", "S", "N", "M", "B", "Z", "")
				      && !StringAt(original, (current - 1), 1,
						   "S", "K", "L", "")) 
                                    {
				      MetaphAdd(primary, "j");
				      MetaphAdd(secondary, "j");
                                    }
			      }
			}
		  }

		if (GetAt(original, current + 1) == 'J')	/* it could happen! */
		    current += 2;
		else
		    current += 1;
		break;

	    case 'K':
		if (GetAt(original, current + 1) != 'H') {
		    if (GetAt(original, current + 1) == 'K')
		        current += 2;
		    else
		        current += 1;

		    MetaphAdd(primary, "k");
		}
		else {
		    /* husky "kh" from arabic */
		    MetaphAdd(primary, "x");
		    current += 2;
		}
		MetaphAdd(secondary, "k");
		break;

	    case 'L':
		if (GetAt(original, current + 1) == 'L')
		  {
		      /* spanish e.g. 'cabrillo', 'gallegos' */
		      if (((current == (length - 3))
			   && StringAt(original, (current - 1), 4, "ILLO",
				       "ILLA", "ALLE", ""))
			  || ((StringAt(original, (last - 1), 2, "AS", "OS", "")
			    || StringAt(original, last, 1, "A", "O", ""))
			   && StringAt(original, (current - 1), 4, "ALLE", "")))
			{
			    MetaphAdd(primary, "l");
			    MetaphAdd(secondary, "");
			    current += 2;
			    break;
			}
		      current += 2;
		  }
		else
		    current += 1;
		MetaphAdd(primary, "l");
		MetaphAdd(secondary, "l");
		break;

	    case 'M':
		if ((StringAt(original, (current - 1), 3, "UMB", "")
		     && (((current + 1) == last)
			 || StringAt(original, (current + 2), 2, "ER", "")))
		    /* 'dumb','thumb' */
		    || (GetAt(original, current + 1) == 'M'))
		    current += 2;
		else
		    current += 1;
		MetaphAdd(primary, "m");
		MetaphAdd(secondary, "m");
		break;

	    case 'N':
		if (GetAt(original, current + 1) == 'Y')
		  {
		    MetaphAdd(primary, "ɲ");
	            current += 2;
		  }
		else
		  {
		    if (GetAt(original, current + 1) == 'N')
		        current += 2;
		    else
		        current += 1;
		    MetaphAdd(primary, "n");
		  }
		MetaphAdd(secondary, "n");
		break;

	    case 0xd1: /* Ñ */
		current += 1;
		MetaphAdd(primary, "ɲ");
		MetaphAdd(secondary, "n");
		break;

	    case 'P':
		if (GetAt(original, current + 1) == 'H')
		  {
		      MetaphAdd(primary, "f");
		      MetaphAdd(secondary, "f");
		      current += 2;
		      break;
		  }

		/* also account for "campbell", "raspberry" */
		if (StringAt(original, (current + 1), 1, "P", "B", ""))
		    current += 2;
		else
		    current += 1;
		MetaphAdd(primary, "p");
		MetaphAdd(secondary, "p");
		break;

	    case 'Q':
		if (GetAt(original, current + 1) == 'U')
                  {
		    MetaphAdd(primary, "kw");
		    current += 1;  /* total of 2 */
		  }
		else
		  {
		    if (GetAt(original, current + 1) == 'Q')
		        current += 2;
		    else
		        current += 1;

		    MetaphAdd(primary, "k'");
		  }

		MetaphAdd(secondary, "k");
		break;

	    case 'R':
		/* french e.g. 'rogier', but exclude 'hochmeier' */
		if ((current == last)
		    && !SlavoGermanic(original)
		    && StringAt(original, (current - 2), 2, "IE", "")
		    && !StringAt(original, (current - 4), 2, "ME", "MA", ""))
		  {
		      MetaphAdd(primary, "");
		      MetaphAdd(secondary, "r");
		  }
		else
		  {
		      MetaphAdd(primary, "r");
		      MetaphAdd(secondary, "r");
		  }

		if (GetAt(original, current + 1) == 'R')
		    current += 2;
		else
		    current += 1;
		break;

	    case 'S':
		/* special cases 'island', 'isle', 'carlisle', 'carlysle' */
		if (StringAt(original, (current - 1), 3, "ISL", "YSL", ""))
		  {
		      current += 1;
		      break;
		  }

		/* special case 'sugar-' */
		if ((current == 0)
		    && StringAt(original, current, 5, "SUGAR", ""))
		  {
		      MetaphAdd(primary, "ʃ");
		      MetaphAdd(secondary, "s");
		      current += 1;
		      break;
		  }

		if (StringAt(original, current, 2, "SH", ""))
		  {
		      /* germanic */
		      if (StringAt
			  (original, (current + 1), 4, "HEIM", "HOEK", "HOLM",
			   "HOLZ", ""))
			{
			    MetaphAdd(primary, "s");
			    MetaphAdd(secondary, "s");
			}
		      else
			{
			    MetaphAdd(primary, "ʃ");
			    MetaphAdd(secondary, "ʃ");
			}
		      current += 2;
		      break;
		  }

		/* italian & armenian */
		if (StringAt(original, current, 3, "SIO", "SIA", "")
		    || StringAt(original, current, 4, "SIAN", ""))
		  {
		      if (!SlavoGermanic(original))
			{
			    MetaphAdd(primary, "s");
			    MetaphAdd(secondary, "ʃ");
			}
		      else
			{
			    MetaphAdd(primary, "s");
			    MetaphAdd(secondary, "s");
			}
		      current += 3;
		      break;
		  }

		/* german & anglicisations, e.g. 'smith' match 'schmidt', 'snider' match 'schneider' 
		   also, -sz- in slavic language altho in hungarian it is pronounced 's' */
		if (((current == 0)
		     && StringAt(original, (current + 1), 1, "M", "N", "L", "W", ""))
		    || StringAt(original, (current + 1), 1, "Z", ""))
		  {
		      MetaphAdd(primary, "s");
		      MetaphAdd(secondary, "ʃ");
		      if (StringAt(original, (current + 1), 1, "Z", ""))
			  current += 2;
		      else
			  current += 1;
		      break;
		  }

		if (StringAt(original, current, 2, "SC", ""))
		  {
		      /* Schlesinger's rule */
		      if (GetAt(original, current + 2) == 'H')
			  /* dutch origin, e.g. 'school', 'schooner' */
			  if (StringAt(original, (current + 3), 2, "OO", "ER", "EN",
			               "UY", "ED", "EM", ""))
			    {
				/* 'schermerhorn', 'schenker' */
				if (StringAt(original, (current + 3), 2, "ER", "EN", ""))
				  {
				      MetaphAdd(primary, "ʃ");
				      MetaphAdd(secondary, "sk");
				  }
				else
                                  {
				      MetaphAdd(primary, "sk");
				      MetaphAdd(secondary, "sk");
                                  }
				current += 3;
				break;
			    }
			  else
			    {
				if ((current == 0) && !IsVowel(original, 3)
				    && (GetAt(original, 3) != 'W'))
				  {
				      MetaphAdd(primary, "ʃ");
				      MetaphAdd(secondary, "s");
				  }
				else
				  {
				      MetaphAdd(primary, "ʃ");
				      MetaphAdd(secondary, "ʃ");
				  }
				current += 3;
				break;
			    }

		      if (StringAt(original, (current + 2), 1, "I", "E", "Y", ""))
			{
			    MetaphAdd(primary, "S");
			    MetaphAdd(secondary, "s");
			    current += 3;
			    break;
			}
		      /* else */
		      MetaphAdd(primary, "sk");
		      MetaphAdd(secondary, "sk");
		      current += 3;
		      break;
		  }

		/* french e.g. 'resnais', 'artois' */
		if ((current == last)
		    && StringAt(original, (current - 2), 2, "AI", "OI", ""))
		  {
		      MetaphAdd(primary, "");
		      MetaphAdd(secondary, "s");
		  }
		else
		  {
		      MetaphAdd(primary, "s");
		      MetaphAdd(secondary, "s");
		  }

		if (StringAt(original, (current + 1), 1, "S", "Z", ""))
		    current += 2;
		else
		    current += 1;
		break;

	    case 'T':
		if (StringAt(original, current, 4, "TION", ""))
		  {
		      MetaphAdd(primary, "ʃ");
		      MetaphAdd(secondary, "ʃ");
		      current += 3;
		      break;
		  }

		if (StringAt(original, current, 3, "TIA", "TCH", ""))
		  {
		      MetaphAdd(primary, "ʃ");
		      MetaphAdd(secondary, "ʃ");
		      current += 3;
		      break;
		  }

		if (StringAt(original, current, 2, "TH", "")
		    || StringAt(original, current, 3, "TTH", ""))
		  {
		      /* special case 'thomas', 'thames' or germanic */
		      if (StringAt(original, (current + 2), 2, "OM", "AM", "")
			  || StringAt(original, 0, 4, "VAN ", "VON ", "")
			  || StringAt(original, 0, 3, "SCH", ""))
			{
			    MetaphAdd(primary, "t");
			    MetaphAdd(secondary, "t");
			}
		      else
			{
			    MetaphAdd(primary, "Θ");
			    MetaphAdd(secondary, "t");
			}
		      current += 2;
		      break;
		  }

		if (StringAt(original, (current + 1), 1, "T", "D", ""))
		    current += 2;
		else
		    current += 1;
		MetaphAdd(primary, "t");
		MetaphAdd(secondary, "t");
		break;

	    case 'V':
		if (GetAt(original, current + 1) == 'V')
		    current += 2;
		else
		    current += 1;
		MetaphAdd(primary, "f");
		MetaphAdd(secondary, "f");
		break;

	    case 'W':
		/* can also be in middle of word */
		if (StringAt(original, current, 2, "WR", ""))
		  {
		      MetaphAdd(primary, "r");
		      MetaphAdd(secondary, "r");
		      current += 2;
		      break;
		  }

		if ((current == 0)
		    && (IsVowel(original, current + 1)
			|| StringAt(original, current, 2, "WH", "")))
		  {
		      /* Wasserman should match Vasserman */
		      if (IsVowel(original, current + 1))
			{
			    MetaphAdd(primary, "a");
			    MetaphAdd(secondary, "f");
			}
		      else
			{
			    /* need Uomo to match Womo */
			    MetaphAdd(primary, "a");
			    MetaphAdd(secondary, "a");
			}
		  }

		/* Arnow should match Arnoff */
		if (((current == last) && IsVowel(original, current - 1))
		    || StringAt(original, (current - 1), 5, "EWSKI", "EWSKY",
				"OWSKI", "OWSKY", "")
		    || StringAt(original, 0, 3, "SCH", ""))
		  {
		      MetaphAdd(primary, "");
		      MetaphAdd(secondary, "f");
		      current += 1;
		      break;
		  }

		/* polish e.g. 'filipowicz' */
		if (StringAt(original, current, 4, "WICZ", "WITZ", ""))
		  {
		      MetaphAdd(primary, "ts");
		      MetaphAdd(secondary, "fx");
		      current += 4;
		      break;
		  }

		/* else skip it */
		current += 1;
		break;

	    case 'X':
		/* french e.g. breaux */
		if (!((current == last)
		      && (StringAt(original, (current - 3), 3, "IAU", "EAU", "")
		       || StringAt(original, (current - 2), 2, "AU", "OU", ""))))
                  {
		      MetaphAdd(primary, "ks");
		      MetaphAdd(secondary, "ks");
                  }
                  

		if (StringAt(original, (current + 1), 1, "C", "X", ""))
		    current += 2;
		else
		    current += 1;
		break;

	    case 'Z':
		/* chinese pinyin e.g. 'zhao' */
		if (GetAt(original, current + 1) == 'H')
		  {
		      MetaphAdd(primary, "j");
		      MetaphAdd(secondary, "j");
		      current += 2;
		      break;
		  }
		else if (StringAt(original, (current + 1), 2, "ZO", "ZI", "ZA", "")
			|| (SlavoGermanic(original)
			    && ((current > 0)
				&& GetAt(original, current - 1) != 'T')))
		  {
		      MetaphAdd(primary, "s");
		      MetaphAdd(secondary, "ts");
		  }
		else
                  {
		    MetaphAdd(primary, "s");
		    MetaphAdd(secondary, "s");
                  }

		if (GetAt(original, current + 1) == 'Z')
		    current += 2;
		else
		    current += 1;
		break;

	    default:
		current += 1;
	    }
        /* printf("PRIMARY: %s\n", primary->str);
        printf("SECONDARY: %s\n", secondary->str);  */
      }


    if (primary->length > KEY_LIMIT)
	SetAt(primary, KEY_LIMIT, '\0');

    if (secondary->length > KEY_LIMIT)
	SetAt(secondary, KEY_LIMIT, '\0');

    *codes = primary->str;
    *++codes = secondary->str;

    DestroyMetaString(original);
    DestroyMetaString(primary);
    DestroyMetaString(secondary);
}


MODULE = Text::TransMetaphone::en_US		PACKAGE = Text::TransMetaphone::en_US


void
trans_metaphone(str)
	unsigned char *	str

        PREINIT:
        unsigned char *codes[2];
	SV* sv;

        PPCODE:
        TransMetaphone_en_US(str, codes);

	// fprintf (stderr, "  Pushing %s\n", codes[0]);
        sv = newSVpv(codes[0], 0);
	SvUTF8_on(sv);
        XPUSHs(sv_2mortal(sv));
        if ((GIMME == G_ARRAY) && strcmp(codes[0], codes[1])) 
          {
		sv = newSVpv(codes[1], 0);
		SvUTF8_on(sv);
		XPUSHs(sv_2mortal(sv));
          } 
        Safefree(codes[0]);
        Safefree(codes[1]);
