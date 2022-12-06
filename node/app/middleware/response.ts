import ERROR from '../utils/error';

export default () => {
  return async function responseDataAndTime(ctx, next) {
    ctx.error = ({ code = 'SYSTEM_ERROR', msg = '请求错误', data = {} }) => {
      ctx.status = 500;
      ctx.body = {
        code: ERROR[code] || ERROR.SYSTEM_ERROR,
        msg,
        data,
      };
    };
    ctx.success = (msg = '请求成功', data = {}) => {
      ctx.status = 200;
      ctx.body = { code: ERROR.SUCCESS, msg, data };
    };

    const start = Date.now();
    await next();
    const cost = Date.now() - start;
    ctx.set('X-Response-Time', `${cost}ms`);
  };
};
