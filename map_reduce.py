import argparse

from pymongo import MongoClient
from bson import Code
from pymongo.collection import Collection


def init_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("host", type=str)
    parser.add_argument("-p", "--port", type=int, default=27017)
    return parser


def main(args):
    client = MongoClient(args.host, args.port, username="root", password="password123")
    mycol: Collection = client.mydb.mycol

    mongo_map = Code("""function() { emit(this.value, 1) }""")
    mongo_reduce = Code("""function(key, values) { return Array.sum(values) }""")
    result: Collection = mycol.map_reduce(mongo_map, mongo_reduce, "result")

    print(list(result.find()))
    client.close()


if __name__ == '__main__':
    main(init_parser().parse_args())
