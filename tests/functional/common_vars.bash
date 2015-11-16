OUT_DIR=$BATS_TEST_DIRNAME/../../exported-artifacts/coverage/functional
echo "#!/bin/bash" > $BATS_TEST_DIRNAME/repoman_coverage
echo "coverage run -a $(which repoman) \"\$@\"" >> $BATS_TEST_DIRNAME/repoman_coverage
chmod +x $BATS_TEST_DIRNAME/repoman_coverage
export PATH=$BATS_TEST_DIRNAME:$PATH
