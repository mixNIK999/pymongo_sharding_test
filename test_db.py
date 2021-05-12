import argparse

from pymongo import MongoClient


def init_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("host", type=str)
    parser.add_argument("-p", "--port", type=int, default=27017)
    return parser


def main(args):
    client = MongoClient(args.host, args.port, username="root", password="password123")
    assert client.is_mongos
    print("Connected")
    stat = client.admin.command({"listShards": 1})
    size = len(stat["shards"])
    print(f"cluster size = {size}")
    client.close()


if __name__ == '__main__':
    main(init_parser().parse_args())
