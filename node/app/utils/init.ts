/**
 * @description 根据../assets/chapter目录内的文件重新生成../assets/book/chapter.json文件
 */

import { Chapter, EggAppConfig } from 'egg';
import fs from 'fs';
import path from 'path';
import moment from 'moment';

export default async (config: EggAppConfig): Promise<Chapter[]> => {
  const pathList = await fs.readdirSync(config.txtPath);

  const chapterList: Chapter[] = [];
  let chapterId = 1;
  for (const fileName of pathList) {
    const chapter = await fs.readFileSync(path.join(config.txtPath, fileName));
    chapterList.push({
      id: chapterId,
      name: fileName.split('.')[0],
      wordCount: chapter.toString().length,
      bookId: 1,
      file: path.join(config.txtPath, fileName),
      time: moment().format('YYYY-MM-DD HH:mm:ss'),
    });
    chapterId += 1;
  }

  fs.writeFileSync(
    config.chapterJsonPath,
    JSON.stringify(chapterList, null, 2),
  );

  return chapterList;
};
