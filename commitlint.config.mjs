export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [2, 'always', ['api', 'web', 'functions', 'infra', 'ops', 'docs', 'ci', 'deps']],
  },
};
