// This file is created by egg-ts-helper@1.33.0
// Do not modify this file!!!!!!!!!

import 'egg';
import ExportResponse from '../../../app/middleware/response';

declare module 'egg' {
  interface IMiddleware {
    response: typeof ExportResponse;
  }
}
