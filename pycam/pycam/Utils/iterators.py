"""
Copyright 2008 Lode Leroy

This file is part of PyCAM.

PyCAM is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PyCAM is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PyCAM.  If not, see <http://www.gnu.org/licenses/>.
"""


class Iterator:
    def __init__(self, seq, start=0):
        self.seq = seq
        self.ind = start

    def __next__(self):
        if self.ind >= len(self.seq):
            return None
        else:
            item = self.seq[self.ind]
            self.ind += 1
            return item

    def insert_before(self, item):
        self.seq.insert(self.ind - 1, item)
        self.ind += 1

    def insert(self, item):
        self.seq.insert(self.ind, item)
        self.ind += 1

    def replace(self, item_old, item_new):
        for i in range(len(self.seq)):
            if self.seq[i] == item_old:
                self.seq[i] = item_new

    def remove(self, item):
        for i in range(len(self.seq)):
            if self.seq[i] == item:
                del self.seq[i]
                if i < self.ind:
                    self.ind -= 1
                return

    def take_next(self):
        if self.ind >= len(self.seq):
            return None
        else:
            return self.seq.pop(self.ind)

    def copy(self):
        return Iterator(self.seq, self.ind)

    def peek(self, i=0):
        if self.ind + i >= len(self.seq):
            return None
        else:
            return self.seq[self.ind + i]

    def remains(self):
        return len(self.seq) - self.ind


class CyclicIterator:
    def __init__(self, seq, start=0):
        self.seq = seq
        self.ind = start
        self.count = len(seq)

    def __next__(self):
        item = self.seq[self.ind]
        self.ind += 1
        if self.ind == len(self.seq):
            self.ind = 0
        return item

    def copy(self):
        return CyclicIterator(self.seq, self.ind)

    def peek(self, i=0):
        idx = self.ind + i
        while idx >= len(self.seq):
            idx -= len(self.seq)
        return self.seq[idx]


if __name__ == "__main__":
    values = [1, 2, 4, 6]
    print("l=", values)
    i = Iterator(values)
    print(i.peek())
    while True:
        val = next(i)
        if val is None:
            break
        if val == 4:
            i.insert_before(3)
            i.insert(5)

    print("l=", values)
    i = Iterator(values)
    print("peek(0)=", i.peek(0))
    print("peek(1)=", i.peek(1))
    print("i.next()=", next(i))
    print("peek(0)=", i.peek(0))
    print("peek(1)=", i.peek(1))

    print("remains=", i.remains())

    print("l=", values)
    sum_value = 0
    i = CyclicIterator(values)
    print("cycle :"),
    while sum_value < 30:
        val = next(i)
        print(val),
        sum_value += val
    print("=", sum_value)

    i = Iterator(values)
    print("l=", values)
    next(i)
    next(i)
    print("next,next : ", i.peek())
    i.remove(2)
    print("remove(2) : ", i.peek())
    i.remove(4)
    print("remove(4) : ", i.peek())
    print("l=", values)
