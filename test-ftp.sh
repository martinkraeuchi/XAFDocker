#!/bin/bash
# FTP Connection Test Script
# Tests various FTP/FTPS configurations to determine server capabilities

FTP_HOST="sl280.web.hostpoint.ch"
FTP_PORT="21"
FTP_USER="skg@harray.net"
FTP_PASSWORD="Bernhardiner09"
FTP_PATH="/xafdocker-backups"

echo "=============================================="
echo "FTP Connection Test"
echo "=============================================="
echo "Host: $FTP_HOST:$FTP_PORT"
echo "User: $FTP_USER"
echo "Path: $FTP_PATH"
echo ""

# Test 1: Plain FTP
echo "Test 1: Plain FTP (no encryption)"
echo "----------------------------------------------"
lftp -c "
    set ftp:ssl-allow no;
    set ftp:ssl-force no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    ls $FTP_PATH;
    bye
" 2>&1 | head -5
echo "Result: $?"
echo ""

# Test 2: Explicit FTPS (AUTH TLS)
echo "Test 2: Explicit FTPS with AUTH TLS"
echo "----------------------------------------------"
lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ftp:ssl-protect-data yes;
    set ftp:ssl-protect-list yes;
    set ssl:verify-certificate no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    ls $FTP_PATH;
    bye
" 2>&1 | head -5
echo "Result: $?"
echo ""

# Test 3: Explicit FTPS without data/list protection
echo "Test 3: Explicit FTPS (control only)"
echo "----------------------------------------------"
lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ftp:ssl-protect-data no;
    set ftp:ssl-protect-list no;
    set ssl:verify-certificate no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    ls $FTP_PATH;
    bye
" 2>&1 | head -5
echo "Result: $?"
echo ""

# Test 4: Implicit FTPS (port 990)
echo "Test 4: Implicit FTPS (port 990)"
echo "----------------------------------------------"
timeout 5 bash -c "cat < /dev/null > /dev/tcp/$FTP_HOST/990" 2>&1
if [ $? -eq 0 ]; then
    echo "Port 990 is open, testing connection..."
    lftp -c "
        set ftp:ssl-allow yes;
        set ftp:ssl-force yes;
        set ssl:verify-certificate no;
        open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p 990 ftps://$FTP_HOST;
        ls $FTP_PATH;
        bye
    " 2>&1 | head -5
    echo "Result: $?"
else
    echo "Port 990 is closed/filtered"
fi
echo ""

# Test 5: Check SSL/TLS capabilities
echo "Test 5: SSL/TLS negotiation details"
echo "----------------------------------------------"
lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ssl:verify-certificate no;
    debug 3;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    bye
" 2>&1 | grep -E "(AUTH|TLS|SSL|FEAT)" | head -10
echo ""

# Test 6: Check SFTP (port 22)
echo "Test 6: SFTP/SSH availability"
echo "----------------------------------------------"
timeout 5 bash -c "cat < /dev/null > /dev/tcp/$FTP_HOST/22" 2>&1
if [ $? -eq 0 ]; then
    echo "Port 22 (SSH/SFTP) is open"
    echo "Checking SSH banner..."
    timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $FTP_USER@$FTP_HOST 2>&1 | head -3
else
    echo "Port 22 is closed/filtered"
fi
echo ""

echo "=============================================="
echo "Test Complete"
echo "=============================================="
