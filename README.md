# Ethernet OverView (`ethov`)

`ethov` is a simple Bash-based tool for providing an overview of network interfaces in Linux. It provides detailed information about physical and virtual network interfaces, including the interface's speed, link status, card name, and additional details such as IP address, MAC address, MTU, and supported speeds.

## Features:
- **Physical Interface Info**: Shows detailed information about network interfaces, including card name, MAC address, MTU, IP address, and available speeds.
- **Virtual Interfaces (Bridges / Bonds)**: Provides detailed information on virtual interfaces, including the member interfaces and their speeds.
- **Link Status**: Displays the current link status (Up/Down) with a color-coded dot icon (🟢/🔴).
- **Speed Information**: Displays available speeds for interfaces and determines the speed for active members of bonds and bridges.
- **Color-Coded Output**: Different network speeds are color-coded for easy identification.

## 📋 Requirements

For `ethov` to work correctly, the following tools must be installed and available in your system:

| Command     | Package Name   | Purpose                                 |
|-------------|----------------|-----------------------------------------|
| `lshw`      | `lshw`          | Retrieves hardware information (e.g., card name) |
| `ethtool`   | `ethtool`       | Gathers interface speed, link status, etc. |
| `ip`        | `iproute2` (usually preinstalled) | Gets IP addresses and interface info |
| `awk`       | `gawk` or `mawk` (usually preinstalled) | Text processing |
| `grep`      | `grep` (usually preinstalled)     | Pattern matching |
| `cat`, `ls` | `coreutils`     | Basic shell utilities |

> ✅ On most Debian/Ubuntu/Proxmox systems, only `lshw` and `ethtool` might need to be installed manually.


## Get the script localy:
1. Clone the repository to your local machine:
   ```bash
   git clone https://github.com/Micinek/ethov.git
   cd ethov
   ```

2. Make the script executable:
   ```bash
   chmod +x ethov.sh
   ```

3. Run the script:
   ```bash
   ./ethov.sh
   ```

## Running the script localy:
Simply run the script to see an overview of all network interfaces on your system:
```bash
./ethov.sh
```

## Running the script directly from GithubRepo:
Simply run the script to see an overview of all network interfaces on your system:
```bash
bash <(curl -s https://raw.githubusercontent.com/Micinek/ethov/refs/heads/main/ethov.sh)
```



The script will display information for each network interface, including:
- **MAC Address**
- **MTU**
- **IP Address (IPv4)**
- **Link Status** (Up/Down)
- **Speed**
- **Supported Speeds** for physical interfaces
- **Member interfaces** for bridges and bonds

## Example Output:
**Physical Interface**
```
=== eth0 — Intel Corporation Ethernet Controller
  MAC: 00:1a:2b:3c:4d:5e
  MTU: 1500
  IP: 192.168.1.10
  Available Speeds: 1000,10000,25000
  Speed: 1000Mb/s
  Link detected: 🟢 YES
```
**Virtual Interface**
```
=== vmbr0 — Unknown
  MAC: 00:1a:2b:3c:4d:5e
  MTU: 1500
  IP: 192.168.11.201/24
  Members (bridge): enp129s0f0
  Available Speeds (from members): 100,1000
  Speed (via enp129s0f0): 1000Mb/s
  Link detected: YES 🟢
```

