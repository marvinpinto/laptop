#!/usr/bin/env python

import imaplib
import subprocess
import time
import os
import fcntl
import sys


USERNAME_FILE = "%s/.i3/fastmail_username.gpg" % os.environ['HOME']
PASSWORD_FILE = "%s/.i3/fastmail_password.gpg" % os.environ['HOME']
REFRESH_INTERVAL = 60*2  # 2 minutes
OUTPUT_FILENAME = "/tmp/unread-mail-count.txt"
LOCKFILE = "/tmp/fastmail-unread-count-lock.pid"


def get_gpg_info(filename):
    return subprocess.check_output(['gpg2', '--batch', '--use-agent', '--decrypt', filename])


def get_unread_mail_count():
    username = get_gpg_info(USERNAME_FILE).strip()
    password = get_gpg_info(PASSWORD_FILE).strip()
    mail = imaplib.IMAP4_SSL("mail.messagingengine.com")
    mail.login(username, password)
    mail.select()
    return len(mail.search(None, 'UnSeen')[1][0].split())


def write_to_file(filename, contents):
    fh = open(filename, "w")
    fh.write('%s\n' % str(contents))
    fh.close()


def main():
    fp = open(LOCKFILE, 'w')
    try:
        fcntl.flock(fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        print("Lock file is in use")
        sys.exit(1)

    while True:
        refresh_interval = REFRESH_INTERVAL
        try:
            unread_count = get_unread_mail_count()
            write_to_file(OUTPUT_FILENAME, unread_count)
        except Exception as e:
            write_to_file(OUTPUT_FILENAME, "ERROR: %s" % e)
            refresh_interval = 10  # try again in 10 seconds
        time.sleep(refresh_interval)


if __name__ == "__main__":
    main()
