import random
import time
from multiprocessing.context import Process
from statistics import mean

from pymongo import MongoClient
import argparse
import multiprocessing as mp

from pymongo.collection import Collection
from pymongo.database import Database


def init_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("host", type=str)
    parser.add_argument("-p", "--port", type=int, default=27017)
    return parser


def init_db(client: MongoClient):
    client.drop_database("mydb")
    mydb: Database = client.mydb
    client.admin.command('enableSharding', "mydb")
    mycol: Collection = mydb.mycol
    client.admin.command('shardCollection', 'mydb.mycol', key={'_id': "hashed"})
    assert mycol.count_documents({}) == 0

    return mydb, mycol


def put(collection: Collection, key, val):
    collection.update_one({"_id": key}, {"$set": {"value": val}}, upsert=True)


def get(collection: Collection, key):
    return collection.find_one({"_id": key})


def worker(keys, host, port):
    random.seed(0)
    client = MongoClient(host, port, username="root", password="password123", maxPoolSize=1)
    mycol = client.mydb.mycol
    my_name = mp.current_process().name
    res = [put(mycol, key, my_name) if (bool(random.getrandbits(1))) else get(mycol, key) for key in keys]
    client.close()
    return res


def gen_keys(key_pool, size):
    return [f"key{random.randint(0, key_pool)}" for _ in range(size)]


def experiment(host, port, worker_number):
    print("stat experiment")
    random.seed(0)
    client = MongoClient(host, port, username="root", password="password123")
    _, _ = init_db(client)
    client.close()
    keys_set = [gen_keys(1000, 500) for _ in range(worker_number)]
    processes = [Process(target=worker, args=(keys, host, port)) for keys in keys_set]
    start = time.time()

    for p in processes:
        p.start()

    for p in processes:
        p.join()

    end = time.time()

    res = end - start
    print(f"{res} sec")

    return res


def main(args):
    interesting_worker_number = [1, 4, 7, 50, 100]
    results = []
    for wn in interesting_worker_number:
        print(f"start experiments with {wn} workers")
        experiments_res = [experiment(args.host, args.port, wn) for _ in range(5)]
        mn = mean(experiments_res)
        print(f"wn = {wn}, mean = {mn}")
        print()
        results.append(mn)
    print(", ".join(map(str, results)))


if __name__ == '__main__':
    main(init_parser().parse_args())
