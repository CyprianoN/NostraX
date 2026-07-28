class MinimalReporter {
  constructor(runner) {
    runner.on("fail", (test, err) => {
      console.error(`\n  ✖ ${test.fullTitle()}`);
      console.error(err.stack || err.message);
    });
  }
}

MinimalReporter.description = "Minimal (failures only)";
module.exports = MinimalReporter;
