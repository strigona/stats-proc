#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

void error(int line, char *buf, int len)
{
    for (int i = 0; i < len; i++) {
        if (buf[i] == 0) {
            buf[i] = ',';
        }
    }
    buf[len] = 0;
    fprintf(stderr, "BADLOG: line %d: %s\n", line, buf);
}

inline char *charfwd(char *p, char c)
{
    while (*p != c) {
        if (*p == 0) {
            return NULL;
        }
        p++;
    }
    return p;
}

inline char *charrev(char *p, char c)
{
    while (*p != c) {
        if (*p == 0) {
            return NULL;
        }
        p--;
    }
    return p;
}

int main(int, char *[])
{
    char buf[256];
    int line = 1;
    while (fgets(buf, sizeof(buf), stdin) != NULL) {
        {
        int len = strlen(buf);
        char *p = buf;
        // first field is date/time stamp
        char *date = p;
        int date_year, date_month, date_day;
        if (sscanf(date, "%d/%d/%d", &date_month, &date_day, &date_year) != 3) {
            goto next;
        }
        if (date_year < 97) {
            date_year += 2000;
        } else {
            date_year += 1900;
        }
        p = charfwd(p, ',');
        if (p == NULL) {
            error(line, buf, len);
            goto next;
        }
        p++;
        // next field is ip address which we don't care about
        p = charfwd(p, ',');
        if (p == NULL) {
            error(line, buf, len);
            goto next;
        }
        *p = 0;
        p++;
        // this is the start of the email address
        char *email = p;
        // now we'll start from the end of the string
        char *q = buf + len;
        if (q[-1] == '\n') {
            q--;
        }
        *q = 0;
        char *endfieldptrs[5]; // up to 5 numeric fields at the end
        int endfields = 0;
        while (endfields < 5) {
            q--;
            if (!isdigit(*q)) {
                if (*q == ',') {
                    *q = 0;
                    endfieldptrs[endfields++] = q+1;
                } else {
                    break;
                }
            }
        }
        char *size, *os, *cpu, *version, *status;
        if (endfields < 4) {
            error(line, buf, len);
            goto next;
        } else if (endfields == 4) {
            size    = endfieldptrs[3];
            os      = endfieldptrs[2];
            cpu     = endfieldptrs[1];
            version = endfieldptrs[0];
            status  = "0";
        } else {
            size    = endfieldptrs[4];
            os      = endfieldptrs[3];
            cpu     = endfieldptrs[2];
            version = endfieldptrs[1];
            status  = endfieldptrs[0];
        }
        int nstatus = atoi(status);
        if (nstatus != 0 && nstatus != 2) {
            error(line, buf, len);
            goto next;
        }
        q--;
        q = charrev(q, ',');
        if (q == NULL) {
            error(line, buf, len);
            goto next;
        }
        char *projectid = q+1;
        projectid[2] = 0;
        if (atoi(projectid) == 26) {
            projectid = "25";
        }
        *q = 0;
        p = email;
        while(1) {
            p = charfwd(p, ',');
            if (p == NULL) {
                break;
            }
            *p = '.';
        }
        printf("%04d%02d%02d,%s,%s,%s,%s,%s,%s\n", date_year, date_month, date_day, email, projectid, size, os, cpu, version);
        }
next:
        line++;
    }
    return 0;
}