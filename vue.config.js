/**
* @Date 2020-12-04
* @author liaoyanyan
* @description 项目配置
*/
const path = require('path')
// const packjson = require('./package.json')

const resolve = dir => {
  return path.join(__dirname, dir)
}

module.exports = {
  lintOnSave: false,
  chainWebpack: config => {
    config.resolve.alias
      .set('@', resolve('src'))
  },
  // 取消文件hash值
  filenameHashing: false,
  // 打包时不生成js.map文件 加速生产环境的构建
  productionSourceMap: false,
  // devServer: {
  //   proxy: {
  //     '/egg': {
  //       target: 'http://127.0.0.1:7001',
  //       changeOrigin: true,
  //       pathRewrite: {
  //         '^/egg': ''
  //       }
  //     }
  //   }
  // }
}
