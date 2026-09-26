#!/usr/bin/env python3
"""
Puts the Football Stars scripts (game/) into a Roblox place file.

    python3 tools/build_place.py "Football_Stars.rbxlx" "Football Stars.rbxlx"

Start from an empty Baseplate place saved out of Studio (File > Save to
File As... > .rbxlx). Everything in it that is not listed below stays
exactly as it was (baseplate, lighting, sky, chat settings).

What it does:
  * puts every script from game/ in its service (a script that is
    already there gets the new source)
  * removes Workspace.SpawnLocation: the map has its own spawn in the middle
    of the stadium plaza (the whole map is built by MapBuilder when the
    server starts)
  * reads the file back and checks every script is there, byte for byte
"""

import os
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, "..", "game")

# game/ folder -> where it goes in the place
SERVICES = {
    "ReplicatedStorage": ["ReplicatedStorage"],
    "ServerScriptService": ["ServerScriptService"],
    "StarterPlayerScripts": ["StarterPlayer", "StarterPlayerScripts"],
}

# Instances to drop: (service class, path below it)
REMOVE = [
    ("Workspace", ["SpawnLocation"]),
]

_referent = [0]


def next_referent():
    _referent[0] += 1
    return "FOOTBALL%d" % _referent[0]


def name_of(item):
    props = item.find("Properties")
    if props is None:
        return None
    node = props.find("string[@name='Name']")
    return node.text if node is not None else None


def find_service(root, class_name):
    for item in root.findall("Item"):
        if item.get("class") == class_name:
            return item
    return None


def find_child(parent, name):
    for item in parent.findall("Item"):
        if name_of(item) == name:
            return item
    return None


def make_script(parent, name, class_name, source):
    item = ET.SubElement(parent, "Item", {"class": class_name, "referent": next_referent()})
    props = ET.SubElement(item, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = source
    ET.SubElement(props, "bool", {"name": "Disabled"}).text = "false"
    return item


def set_source(item, source):
    props = item.find("Properties")
    node = props.find("ProtectedString[@name='Source']")
    if node is None:
        node = ET.SubElement(props, "ProtectedString", {"name": "Source"})
    node.text = source


def class_for(filename):
    if filename.endswith(".server.lua"):
        return "Script"
    if filename.endswith(".client.lua"):
        return "LocalScript"
    return "ModuleScript"


def instance_name(filename):
    return filename.replace(".server.lua", "").replace(".client.lua", "").replace(".lua", "")


def container_for(root, service_path):
    service = find_service(root, service_path[0])
    if service is None:
        sys.exit("the place has no %s service" % service_path[0])
    container = service
    for step in service_path[1:]:
        found = find_child(container, step)
        if found is None:
            sys.exit("the place has no %s.%s" % (service_path[0], step))
        container = found
    return container


def scripts():
    """(service path, instance name, class, source) for every script."""
    for folder, service_path in SERVICES.items():
        directory = os.path.join(GAME, folder)
        for filename in sorted(os.listdir(directory)):
            if not filename.endswith(".lua"):
                continue
            with open(os.path.join(directory, filename), "r", encoding="utf-8", newline="") as handle:
                source = handle.read()
            yield service_path, instance_name(filename), class_for(filename), source


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: build_place.py <input.rbxlx> <output.rbxlx>")
    source_path, output_path = sys.argv[1], sys.argv[2]
    tree = ET.parse(source_path)
    root = tree.getroot()
    replaced, added, removed = [], [], []

    for service_class, path in REMOVE:
        service = find_service(root, service_class)
        parent, node = service, service
        for step in path:
            parent = node
            node = find_child(parent, step) if parent is not None else None
            if node is None:
                break
        if node is not None and node is not service:
            parent.remove(node)
            removed.append("%s.%s" % (service_class, ".".join(path)))

    for service_path, name, class_name, source in scripts():
        container = container_for(root, service_path)
        where = ".".join(service_path + [name])
        existing = find_child(container, name)
        if existing is not None and existing.get("class") == class_name:
            set_source(existing, source)
            replaced.append(where)
        else:
            if existing is not None:
                container.remove(existing)
            make_script(container, name, class_name, source)
            added.append(where)

    tree.write(output_path, encoding="utf-8", xml_declaration=True)

    # read it back: every script must be there, with exactly our source
    check = ET.parse(output_path).getroot()
    bad = []
    count = 0
    for service_path, name, class_name, source in scripts():
        item = find_child(container_for(check, service_path), name)
        node = item.find("Properties").find("ProtectedString[@name='Source']") if item is not None else None
        if item is None or item.get("class") != class_name or node is None or (node.text or "") != source:
            bad.append(".".join(service_path + [name]))
        count += 1
    if find_child(find_service(check, "Workspace"), "SpawnLocation") is not None:
        bad.append("Workspace.SpawnLocation is still there")

    print("added %d scripts, replaced %d" % (len(added), len(replaced)))
    for entry in added + replaced:
        print("   " + entry)
    for entry in removed:
        print("removed " + entry)
    if bad:
        sys.exit("CHECK FAILED: " + ", ".join(bad))
    print("checked %d scripts byte for byte: OK" % count)
    print("wrote %s (%.0f KB)" % (output_path, os.path.getsize(output_path) / 1024))


if __name__ == "__main__":
    main()
