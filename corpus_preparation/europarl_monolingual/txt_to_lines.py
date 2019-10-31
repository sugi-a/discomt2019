import sys, os, codecs, re
from collections import deque
from nltk.tokenize import sent_tokenize

MIN_DOC_LINES = 5

patt_chapter = re.compile(r'<CHAPTER .*?>')
patt_ignore = re.compile(r'<.+?>|\(.+?\)')
patt_speaker = re.compile(r'<SPEAKER .*?>')

ndocs, nsents = 0, 0
q = deque()
talk_started = False
for i, line in enumerate(sys.stdin):
    if i % 100000 == 0:
        sys.stderr.write('{}\t\t\r'.format(i))

    if patt_chapter.match(line):
        # <CHAPTER> is the start symbol of documents

        # write the data of the previous chapter
        if len(q) >= MIN_DOC_LINES:
            for l in q:
                print(l)
            print('')
            ndocs += 1; nsents += len(q)

        # reset the buffer and `talk_started`
        q.clear()
        talk_started = False
    elif patt_speaker.match(line):
        # after the <CHAPTER> tag, some description of the chapter, which is not a speech, might come first. after the first <SPEAKER> tag in the chapter, all text lines are speech.
        talk_started = True
    elif not patt_ignore.match(line) and talk_started:
        # ignore lines starting with a xml tag or (...)
        q.extend(sent_tokenize(line))

if len(q) >= MIN_DOC_LINES:
    for l in q:
        print(l)
    print('')

sys.stderr.write('#sent: {}, #docs: {}, sents/docs: {}\t\t\n'.format(nsents, ndocs, nsents/ndocs))
