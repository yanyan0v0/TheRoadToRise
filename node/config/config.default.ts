import { EggAppConfig, EggAppInfo, PowerPartial } from 'egg';
import path from 'path';

export default (appInfo: EggAppInfo) => {
  const config = {} as PowerPartial<EggAppConfig>;

  // override config from framework / plugin
  // use for cookie sign key, should change to your own and keep security
  config.keys = appInfo.name + '_1669892819273_2733';

  // add your egg config in here
  config.middleware = [ 'response' ];

  // 存放章节文件的目录
  config.txtPath = path.join(__dirname, '../app/assets/chapter');

  // 存放章节json文件的目录
  config.chapterJsonPath = path.join(
    __dirname,
    '../app/assets/book/chapter.json',
  );

  // 解决本地请求跨域问题
  config.security = {
    csrf: {
      enable: false,
      ignoreJSON: true,
    },
    domainWhiteList: [ 'http://localhost:5173' ],
  };
  config.cors = {
    origin: '*',
    allowMethods: 'GET,HEAD,PUT,POST,DELETE,PATCH',
  };

  // the return config will combines to EggAppConfig
  return {
    ...config,
  };
};
