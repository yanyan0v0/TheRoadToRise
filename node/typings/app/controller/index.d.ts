// This file is created by egg-ts-helper@1.33.0
// Do not modify this file!!!!!!!!!

import 'egg';
import ExportChapter from '../../../app/controller/chapter';
import ExportHome from '../../../app/controller/home';

declare module 'egg' {
  interface IController {
    chapter: ExportChapter;
    home: ExportHome;
  }
}
