import { EggAppConfig, EggAppInfo, PowerPartial } from 'egg';
import path from 'path';

export default (appInfo: EggAppInfo) => {
  const config = {} as PowerPartial<EggAppConfig>;

  // override config from framework / plugin
  // use for cookie sign key, should change to your own and keep security
  config.keys = appInfo.name + '_1669892819273_2733';

  // add your egg config in here
  config.middleware = ['response'];

  // 存放章节文件的目录
  config.txtPath = path.join(__dirname, '../app/assets/chapter');

  // 章节txt文件目录名称
  config.chapterTxtName = 'txt';

  // 章节json文件名称
  config.chapterJsonName = 'chapter.json';

  // 解决本地请求跨域问题
  config.security = {
    csrf: {
      enable: false,
      ignoreJSON: true,
    },
    domainWhiteList: ['http://localhost:5173'],
  };
  config.cors = {
    origin: '*',
    allowMethods: 'GET,HEAD,PUT,POST,DELETE,PATCH',
  };

  // 渲染模板
  config.view = {
    defaultViewEngine: 'nunjucks',
    mapping: {
      '.html': 'nunjucks',
    },
  };

  // the return config will combines to EggAppConfig
  return {
    ...config,
  };
};
