module.exports = {
  root: true,
  env: {
    node: true,
    browser: true,
    es6: true
  },
  globals: {
    RTXMemberMap: false
  },
  rules: {
    eqeqeq: 0,
    'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-var': 2,
    'no-param-reassign': 0
  }
}
