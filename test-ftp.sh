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

# Test 7: Upload and delete test file (Plain FTP)
echo "Test 7: Upload/Delete test file (Plain FTP)"
echo "----------------------------------------------"
TEST_FILE="/tmp/ftp-test-$(date +%s).txt"
echo "Test file created at $(date)" > "$TEST_FILE"
echo "Created test file: $TEST_FILE"
lftp -c "
    set ftp:ssl-allow no;
    set ftp:ssl-force no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    put -O \"$FTP_PATH\" \"$TEST_FILE\";
    ls \"$FTP_PATH/$(basename $TEST_FILE)\";
    rm \"$FTP_PATH/$(basename $TEST_FILE)\";
    bye
" 2>&1
RESULT=$?
rm -f "$TEST_FILE"
if [ $RESULT -eq 0 ]; then
    echo "✓ Upload and delete successful"
else
    echo "✗ Upload or delete failed (exit code: $RESULT)"
fi
echo ""

# Test 8: Upload and delete test file (Explicit FTPS)
echo "Test 8: Upload/Delete test file (Explicit FTPS)"
echo "----------------------------------------------"
TEST_FILE="/tmp/ftp-test-$(date +%s).txt"
echo "Test file created at $(date)" > "$TEST_FILE"
echo "Created test file: $TEST_FILE"
lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ftp:ssl-protect-data yes;
    set ftp:ssl-protect-list yes;
    set ssl:verify-certificate no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    put -O \"$FTP_PATH\" \"$TEST_FILE\";
    ls \"$FTP_PATH/$(basename $TEST_FILE)\";
    rm \"$FTP_PATH/$(basename $TEST_FILE)\";
    bye
" 2>&1
RESULT=$?
rm -f "$TEST_FILE"
if [ $RESULT -eq 0 ]; then
    echo "✓ Upload and delete successful (encrypted)"
else
    echo "✗ Upload or delete failed (exit code: $RESULT)"
fi
echo ""

# Test 9: Upload and delete specific file "testonly.txt"
echo "Test 9: Upload/Delete testonly.txt (Explicit FTPS)"
echo "----------------------------------------------"
TEST_FILE="/tmp/testonly.txt"
echo "This is a test file created at $(date)" > "$TEST_FILE"
echo "File size: $(stat -c%s "$TEST_FILE") bytes"
echo ""

echo "Step 1: Uploading testonly.txt..."
lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ftp:ssl-protect-data yes;
    set ftp:ssl-protect-list yes;
    set ssl:verify-certificate no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    put -O \"$FTP_PATH\" \"$TEST_FILE\";
    bye
" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Upload successful"
else
    echo "✗ Upload failed"
fi
echo ""

echo "Step 2: Verifying file exists on server..."
lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ftp:ssl-protect-data yes;
    set ftp:ssl-protect-list yes;
    set ssl:verify-certificate no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    ls -l \"$FTP_PATH/testonly.txt\";
    bye
" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ File verified on server"
else
    echo "✗ File not found on server"
fi
echo ""

echo "Step 3: Deleting testonly.txt..."
lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ftp:ssl-protect-data yes;
    set ftp:ssl-protect-list yes;
    set ssl:verify-certificate no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    rm \"$FTP_PATH/testonly.txt\";
    bye
" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Delete successful"
else
    echo "✗ Delete failed"
fi
echo ""

echo "Step 4: Verifying file was deleted..."
VERIFY_OUTPUT=$(lftp -c "
    set ftp:ssl-allow yes;
    set ftp:ssl-force yes;
    set ftp:ssl-protect-data yes;
    set ftp:ssl-protect-list yes;
    set ssl:verify-certificate no;
    open -u \"$FTP_USER\",\"$FTP_PASSWORD\" -p $FTP_PORT ftp://$FTP_HOST;
    ls -l \"$FTP_PATH/testonly.txt\";
    bye
" 2>&1)
if [ -z "$VERIFY_OUTPUT" ]; then
    echo "✓ File successfully deleted from server"
else
    echo "✗ File still exists on server:"
    echo "$VERIFY_OUTPUT"
fi

# Cleanup local test file
rm -f "$TEST_FILE"
echo ""

echo "=============================================="
echo "Test Complete"
echo "=============================================="
