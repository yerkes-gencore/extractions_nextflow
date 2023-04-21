#!/usr/bin/env python3

import sys
import csv
#from xml.dom.minidom import parse, parseString
import xml.etree.ElementTree as ET
dom = ET.parse(sys.argv[1])
root = dom.getroot()

row_headers = ['Flowcell', 'Project', 'Sample', 'Barcode', 'Lane', 'BarcodeCount', 'PerfectBarcodeCount', 'OneMismatchBarcodeCount', 'Percent perfect', 'Percent one mismatch']

with open(sys.argv[2], 'w') as fo:
    writer = csv.writer(fo)
    writer.writerow(row_headers)
    for flowcell in root:
        for project in flowcell:
            for sample in project:
                for barcode in sample:
                    if barcode != 'all':
                        for lane in barcode:
                            row = {key: '' for key in row_headers}
                            row['Flowcell'] = flowcell.attrib['flowcell-id']
                            row['Project'] = project.attrib['name']
                            row['Sample'] = sample.attrib['name']
                            row['Barcode'] = barcode.attrib['name']
                            row['Lane'] = lane.attrib['number']
                            #print(flowcell.attrib['flowcell-id'], project.attrib['name'], sample.attrib['name'], barcode.attrib['name'], lane.attrib['number'])
                            # print(lane.attrib)
                            #count_types = lane.findall('*')
                            for count_type in lane:
                                #print(count_type.attrib)
                                row[count_type.tag] = float(count_type.text)
                            if row['PerfectBarcodeCount'] != '':
                                percent_perfect = 100 * row['PerfectBarcodeCount'] / row['BarcodeCount']
                                row['Percent perfect'] = '{:.2f}%'.format(percent_perfect)
                            if row['OneMismatchBarcodeCount'] != '':
                                percent_mismatch = 100 * row['OneMismatchBarcodeCount'] / row['BarcodeCount']
                                row['Percent one mismatch'] = '{:.2f}%'.format(percent_mismatch)
                            row = [row[key] for key in row_headers]
                            writer.writerow(row)



    # if node.nodeType == node.ELEMENT_NODE:
    #     print(node.getAttribute('flowcell-id'))
    # if node.nodeType == node.ELEMENT_NODE:
        # print(node.nodeType)
        # print(node.ELEMENT_NODE)
        # for node_1 in node.childNodes:
        #     if node_1.nodeType == node_1.ELEMENT_NODE: