#!/bin/sh
# Watch udisks2 over the system D-Bus and print "refresh" whenever a drive is
# attached, detached, mounted, or unmounted. Zero CPU while idle: dbus-monitor
# blocks until the next signal arrives.
#
# QML runs this as a long-lived Process and re-runs removable.sh once per line.
# Signals watched:
#   InterfacesAdded / InterfacesRemoved  -> device attached / detached
#   PropertiesChanged containing "MountPoints" -> volume mounted / unmounted
dbus-monitor --system \
  "type='signal',sender='org.freedesktop.UDisks2',interface='org.freedesktop.DBus.ObjectManager'" \
  "type='signal',sender='org.freedesktop.UDisks2',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" \
  2>/dev/null | while IFS= read -r line; do
  case "$line" in
    *member=InterfacesAdded*|*member=InterfacesRemoved*) echo refresh ;;
    *'"MountPoints"'*) echo refresh ;;
  esac
done
