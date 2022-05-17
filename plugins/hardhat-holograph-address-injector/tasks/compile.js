const { TASK_COMPILE } = require('hardhat/builtin-tasks/task-names');

task(TASK_COMPILE, async function (args, hre, runSuper) {
  if (hre.config.holographAddressInjector.runOnCompile) {
    await hre.run('inject-holograph-address');
  }

  await runSuper();
});
