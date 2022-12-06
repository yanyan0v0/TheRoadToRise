// This file is created by egg-ts-helper@1.33.0
// Do not modify this file!!!!!!!!!

import 'egg';
import ExportAuthor from '../../../app/controller/author';
import ExportBook from '../../../app/controller/book';
import ExportChapter from '../../../app/controller/chapter';
import ExportHome from '../../../app/controller/home';

declare module 'egg' {
  interface IController {
    author: ExportAuthor;
    book: ExportBook;
    chapter: ExportChapter;
    home: ExportHome;
  }
}
