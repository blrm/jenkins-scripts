lein clean, deps 
echo "PRODUCT_URL: $PRODUCT_URL"
lein trampoline run \
--server-url "$PRODUCT_URL" \
--admin-user "$ADMIN_USER" \
--admin-password "$ADMIN_PASSWORD" \
--sync-repo "$SYNC_TEST_REPO" \
--num-threads $CONCURRENT_SESSIONS \
--selenium-address "$SELENIUM_ADDRESS" \
--deltacloud-url "$DELTACLOUD_URL" \
--deltacloud-user "$DELTACLOUD_USER" \
--deltacloud-password "$DELTACLOUD_PASSWORD" \
--deltacloud-image-id "$DELTACLOUD_IMAGE_ID" \
$TEST_GROUP

