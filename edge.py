#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
    формирование HTML-файлов по ссылкам в edge Bookmarks
"""
# pylint: disable=W,C
__version__ = "0.1.10"

import os
import sys
from datetime import datetime, timedelta
import socket
# from urllib.parse import urlparse, urlunparse
# from linkpreview import Link, LinkPreview, LinkGrabber
import fnmatch
import argparse

import sqlite3

import json
# import requests

sys.path.insert(1, os.path.join(sys.path[0], 'D:\\ownCloud\\test\\Lib\\'))

from python_hosts import Hosts, HostsEntry
# from python_hosts.exception import InvalidComment

from tools import *

# value["DEBUG"] = True

datenow = int(datetime.now().timestamp())  # текущее время
datetoday = datenow//86400*86400           # начало суток

bookmarks = 'Bookmarks.json'

vers = 'Версия {} от {}'.format(__version__, datetime.fromtimestamp(os.path.getmtime(os.path.join(os.path.abspath(os.path.dirname(__file__)), os.path.basename(sys.argv[0])))).strftime('%d.%m.%Y %H:%M.'))
print(f"{os.path.splitext(os.path.basename(sys.argv[0]))[0]} - формирование HTML-файла по ссылкам в edge Bookmarks\n{vers}")

OS = platform.system()
print('Platform ' + OS)
print('Python version ' + sys.version.split(' ')[0])

parser = argparse.ArgumentParser(description="Формирование HTML-файлов по ссылкам в edge Bookmarks.")
parser.add_argument("-b", "--bookmarks", help="Разбирать содержимое файла Bookmarks.json", action="store_true")
parser.add_argument("-H", "--hosts",     help="Формировать hosts.ics", action="store_true")
parser.add_argument("-i", "--ip",        help="Обновлять IP-адреса страниц", action="store_true")
parser.add_argument("-P", "--preview",   help="Формировать preview.html", action="store_true")
parser.add_argument("-p", "--renew",     help="Обновлять изображения для preview.html", action="store_true")
parser.add_argument("-V", "--edge",      help="Формировать edge.html", action="store_true")
parser.add_argument("-q", "--request",   help="Делать запрос на смену режима VPN, если не все ссылки открылись", action="store_true")
parser.add_argument("-n", "--numcols",   help="Число колонок в таблице preview", nargs="?", default=7, type=int)
args = parser.parse_args()

# число колонок в строке экспесс-панели
COLS = args.numcols if args.numcols > 1 else 7

if args.hosts:
    hostsFile = 'hosts.ics' 
    if os.path.exists(hostsFile):
        os.remove(hostsFile)
    hosts = Hosts(path=hostsFile)
else:
    hosts = None

# print(f"os.environ: #10 {os.environ["PYGAME_HIDE_SUPPORT_PROMPT"]}")

con = sqlite3.connect("edge.db", detect_types=sqlite3.PARSE_DECLTYPES|sqlite3.PARSE_COLNAMES, autocommit=True)
con.row_factory = sqlite3.Row
crs = con.cursor()

pass

crs.close()
con.close()

sys.exit(0)
