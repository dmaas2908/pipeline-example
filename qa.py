#!/usr/bin/python3
# qa.py
# See README.md

import sys, re, urllib.request, urllib.parse, subprocess


# requires: filename of csv, returns: nested dictionary { int(test_number) : { str(url), int(httpcode), str(response) } }
def readTestDataFromCSV(filenm):
  i = 0
  with open(filenm, 'r') as file:
    for line in file:
      print("i:", str(i), "line:", line)
      (url,code,text)=line.strip().split(',')
      print("url:", url, "code:", code, "text:", text)
      try:
        testdata_dict.update({ i : { 'url' : url, 'httpcode' : int(code), 'response' : text } })
      except NameError:
        testdata_dict = { i : { 'url' : url.strip(), 'httpcode' : int(code.strip()), 'response' : text.strip() } }
        print("dictionary first line:", testdata_dict)
      i = i + 1
  print("final dict:", testdata_dict)
  return testdata_dict
      
# requires: nada, returns: ingress ip from kubectl (str)
def getIngressIP():
  try:
    output = subprocess.getoutput('kubectl get ingress | grep ingress-config | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"')
  except:
    print("There was an error getting the ingress ip address using kubectl")
    exit()
  return output

def usage():
  print("Usage:", sys.argv[0], "<filename.csv>")
  exit()
  
#requires: nested dictionary of test data from csv file, returns number of failures
def compareTestDataToHTTPResp(testdata):
  ipaddr = getIngressIP()
  failures = 0
  
  for i, data in testdata.items():
    print("Test " + str(i) + " - http://" + ipaddr + data['url'])
    try:
      urlh = urllib.request.urlopen("http://" + ipaddr + data['url'])
    except urllib.error.HTTPError:
      pass
    tmpcode=urlh.getcode()
    rawresponse=urlh.read().decode('utf-8')

  
    if int(tmpcode) != data['httpcode']:
      print("Failure - site http code of", str(tmpcode), "does not match expected value of", str(data['httpcode']))
      failures = failures + 1
      continue
    if not data['response'] in rawresponse:
      print("Failure - site response of", rawresponse, "does not match expected substring of", data['response'])
      failures = failures + 1
      continue
    print("Success - test number ", str(i), "was successfully validated")
  
  print("Total failed tests:", failures)
  print("Out of", str(len(testdata)), "total tests")
    
      
      
    

 

def main():
  if len(sys.argv) != 2:
    usage()
  else:
    testdata = readTestDataFromCSV(sys.argv[1].strip())
    compareTestDataToHTTPResp(testdata)
    
main()
