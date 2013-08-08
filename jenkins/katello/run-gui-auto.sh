lein do clean, deps 
echo "PRODUCT_URL: $PRODUCT_URL"
lein trampoline run \
--server-url "$PRODUCT_URL" \
--admin-user "$ADMIN_USER" \
--admin-password "$ADMIN_PASSWORD" \
--sync-repo "$SYNC_TEST_REPO" \
--num-threads $CONCURRENT_SESSIONS \
--selenium-address "$SELENIUM_ADDRESS" \
--ovirt-url "$OVIRT_URL" \
--ovirt-user "$OVIRT_USER" \
--ovirt-password "$OVIRT_PASSWORD" \
--ovirt-template "$OVIRT_TEMPLATE_NAME" \
--ovirt-cluster "$OVIRT_CLUSTER" \
--locale "$LOCALE" \
$TEST_GROUP

