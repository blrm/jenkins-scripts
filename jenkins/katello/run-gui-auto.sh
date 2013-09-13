ARGS=()
function add-arg {
    if [[ -n $2 ]]; then
        ARGS+=($1 $2)
    fi
}

lein do clean, deps 
echo "PRODUCT_URL: $PRODUCT_URL"

add-arg --server-url "$PRODUCT_URL" 
add-arg --admin-user "$ADMIN_USER" 
add-arg --admin-password "$ADMIN_PASSWORD" 
add-arg --sync-repo "$SYNC_TEST_REPO" 
add-arg --num-threads $CONCURRENT_SESSIONS 
add-arg --sauce-user "$SAUCE_USER" 
add-arg --sauce-key "$SAUCE_KEY" 
add-arg --selenium-address "$SELENIUM_ADDRESS" 
add-arg --ovirt-url "$OVIRT_URL" 
add-arg --ovirt-user "$OVIRT_USER" 
add-arg --ovirt-password "$OVIRT_PASSWORD" 
add-arg --ovirt-template "$OVIRT_TEMPLATE_NAME" 
add-arg --ovirt-cluster "$OVIRT_CLUSTER" 
add-arg --locale "$LOCALE" 

lein trampoline run ${ARGS[*]} $TEST_GROUP


