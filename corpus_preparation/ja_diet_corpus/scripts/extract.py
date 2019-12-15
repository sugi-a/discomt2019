#!/usr/bin/env python
import sys, os, codecs, re
import xml.etree.ElementTree as ET

# load xml data as binary (original Kokkai Corpus is in utf-16)
data = ET.fromstring(sys.stdin.buffer.read())

# convert to utf-8
data = ET.tostring(data, encoding='unicode')

# remove <info /> tags
data = re.sub(r'<info [^>]*?/>', '', data)

# Load XML
root = ET.fromstring(data)

# <body> = document
count = 0
for body in root.iterfind('.//body'):
    # extract speech
    texts = [l.text for l in body.iterfind('.//utterance/l') if l.text is not None]

    # split sentences
    sentences = []
    eos_pattern = ('。', '……')
    for text in texts:
        p_depth = 0
        sent_start = 0
        for i in range(len(text)):
            if any(text[max(i-len(patt) + 1, 0):i+1] == patt for patt in eos_pattern) and p_depth==0:
                sentences.append(text[sent_start: i+1])
                sent_start = i + 1
            elif text[i] == '「':
                p_depth += 1
            elif text[i] == '」':
                p_depth -= 1

    # remove white spaces
    sentences = [sent.strip() for sent in sentences]

    # output
    for sent in sentences:
        print(sent)
    print('')

    # log
    count += len(sentences)
    sys.stderr.write('{}\r'.format(count))

