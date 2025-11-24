# ESPHome

ESPHome is a system to control ESP8266/ESP32 devices with simple yet powerful configuration files and control them remotely through Home Automation systems.

## Deployment Architecture

- **Namespace**: `home-assistant` (shared with Home Assistant)
- **Node Affinity**: Pinned to `worker` node (same as Home Assistant)
- **Network Mode**: `hostNetwork: true` for mDNS discovery of ESP devices
- **Storage**: 5Gi Longhorn PVC for configuration files

## Access

- **Ingress (Tailscale Funnel)**: https://esphome.tabby-carp.ts.net/
- **NodePort**: http://worker:30652/
- **Internal (from Home Assistant)**: http://esphome.home-assistant.svc.cluster.local/

## Why hostNetwork?

ESPHome uses mDNS (multicast DNS) to discover ESP devices on the local network. This requires:
1. Access to the host's network interfaces
2. Ability to send/receive multicast packets
3. Direct access to devices on the local LAN (192.168.1.0/24)

Using `hostNetwork: true` allows ESPHome to:
- Discover ESP devices via mDNS
- Flash firmware to ESP devices over WiFi (OTA updates)
- Communicate with ESP devices on the local network

## Integration with Home Assistant

After deploying ESPHome, you can integrate it with Home Assistant:

1. Open Home Assistant: https://home-assistant.tabby-carp.ts.net/
2. Go to **Settings** → **Devices & Services** → **Add Integration**
3. Search for **ESPHome**
4. Enter the ESPHome server URL: `http://esphome.home-assistant.svc.cluster.local`
5. Click **Submit**

Alternatively, you can use the internal service name since both are in the same namespace:
- Service name: `esphome`
- Port: `80`

## Creating ESP Device Configurations

1. Access ESPHome dashboard: https://esphome.tabby-carp.ts.net/
2. Click **+ NEW DEVICE**
3. Follow the wizard to create a new device configuration
4. Edit the YAML configuration as needed
5. Click **INSTALL** to flash the firmware to your ESP device

## OTA Updates

Once an ESP device is configured and connected to WiFi, you can update it wirelessly:
1. Make changes to the device configuration in ESPHome dashboard
2. Click **INSTALL** → **Wirelessly**
3. ESPHome will compile and upload the new firmware over WiFi

## Storage

Configuration files are stored in a Longhorn PVC (`esphome`) mounted at `/config` in the container.

## Backup

The ESPHome PVC should be included in Longhorn's backup schedule. To manually backup:

```bash
# Create a backup
kubectl exec -n longhorn-system <longhorn-manager-pod> -- \
  longhorn-manager backup create pvc-esphome

# List backups
kubectl exec -n longhorn-system <longhorn-manager-pod> -- \
  longhorn-manager backup list pvc-esphome
```

## Troubleshooting

### ESP devices not discovered

1. Verify ESPHome is using hostNetwork:
   ```bash
   kubectl get pod -n home-assistant -l app=esphome -o jsonpath='{.items[0].spec.hostNetwork}'
   # Should return: true
   ```

2. Check if ESPHome can reach the local network:
   ```bash
   kubectl exec -n home-assistant <esphome-pod> -- ping -c 3 192.168.1.1
   ```

3. Verify mDNS is working:
   ```bash
   kubectl exec -n home-assistant <esphome-pod> -- avahi-browse -a -t
   ```

### Cannot flash ESP device

1. For initial flash, you need to connect the ESP device via USB to your computer
2. Use ESPHome's web-based installer: https://web.esphome.io/
3. After initial flash, use OTA updates from the ESPHome dashboard

### ESPHome pod not starting

Check logs:
```bash
kubectl logs -n home-assistant -l app=esphome
```

Check events:
```bash
kubectl get events -n home-assistant --sort-by='.lastTimestamp'
```

