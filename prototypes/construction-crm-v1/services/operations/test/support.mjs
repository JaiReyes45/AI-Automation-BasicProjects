import pg from 'pg';
export function testPool(){const url=process.env.OPS_TEST_DATABASE_URL;if(!url||!url.includes('/construction_ops_test'))throw new Error('A disposable operations DB is required; run npm run test:operations-db');return new pg.Pool({connectionString:url,max:6});}
