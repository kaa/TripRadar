
from lxml import html
import requests
import csv
import json
import itertools

def rowkey(row):
    return row["id"][:-2]
    
def maprow(row):
    print(row[0])
    page = requests.get('http://kansalaisen.karttapaikka.fi/koordinaatit/muunnos.html?x='+row[8]+'&y='+row[7]+'&srsName=NLSFI%3AETRS-TM35&lang=fi')
    tree = html.fromstring(page.content)
    lat = tree.xpath('//table[1]/tr[5]/td[2]/text()[1]')
    lng = tree.xpath('//table[1]/tr[5]/td[3]/text()[1]')
    return {"id": row[0], "weatherStationId": row[1], "name": row[2], "direction": row[3], "roadNr": row[4], "lat": lat[0], "lng": lng[0]}

points = []
with open("cameras.csv", "rb") as csvfile:
    reader = csv.reader(csvfile, delimiter=";")
    reader.next()
    sorted = sorted([maprow(row) for row in reader], key=rowkey)
    for key, group in itertools.groupby(sorted, rowkey):
        listedGroup = list(group)
        points.append({
            "id": key, "name": listedGroup[0]["name"], 
            "weatherStationId": listedGroup[0]["weatherStationId"],
            "roadNr": listedGroup[0]["roadNr"],
            "lat": listedGroup[0]["lat"],
            "lng": listedGroup[0]["lng"],
            "directions": [{"id": t["id"], "direction": t["direction"]} for t in listedGroup]
        })

with open("cameras.json", "wb") as jsonfile:
    json.dump(points, jsonfile)
            
