/**
 * @description 根据../assets/chapter目录内的文件重新生成对应的/chapter.json文件
 */

import { Chapter, EggApplication } from 'egg';
import fs from 'fs';
import path from 'path';
import BOOK_LIST from '../assets/json/book.json';
import moment from 'moment';

export default async ({ config, loggers }: EggApplication): Promise<void> => {
  const pathList = await fs.readdirSync(config.txtPath);

  for (const bookName of pathList) {
    const book = BOOK_LIST.find(item => item.name === bookName);
    if (!book) continue;

    const chapterPathList = await fs.readdirSync(path.join(config.txtPath, bookName, config.chapterTxtName));
    try {
      const { default: CHAPTER_LIST } = await import(path.join(config.txtPath, bookName, config.chapterJsonName));
      if (CHAPTER_LIST && CHAPTER_LIST.length === chapterPathList.length) continue;
    } catch (error) {
      loggers.warning(`${bookName}未生成${config.chapterJsonName}`);
    }

    let chapterId = 1;
    const chapterList: Chapter[] = [];
    for (const chapterName of chapterPathList) {
      const chapter = await fs.readFileSync(path.join(config.txtPath, bookName, config.chapterTxtName, chapterName));
      chapterList.push({
        id: chapterId,
        name: chapterName.split('.')[0],
        // 只统计汉字
        wordCount: chapter.toString().match(/[\u4e00-\u9fa5]/g)?.length || 0,
        bookId: book.id,
        file: path.join(config.txtPath, bookName, config.chapterTxtName, chapterName),
        time: moment().format('YYYY-MM-DD HH:mm:ss'),
      });
      chapterId += 1;
    }
    fs.writeFileSync(path.join(config.txtPath, bookName, config.chapterJsonName), JSON.stringify(chapterList, null, 2));
  }
};
