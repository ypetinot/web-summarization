/*
Copyright 2010-2011 Kevin Gimpel

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
//
// Support tools for using Google hash maps/sets. Contains SuperFastHash and
// MurmurHash*.
//
// author: Kevin Gimpel
// date created: 3/20/2010

#ifndef HASHING_H_
#define HASHING_H_

#include <string>
// the following block is for the SuperFastHash function from Paul Hsieh (http://www.azillionmonkeys.com/qed/hash.html)
#include "stdint.h"
#undef get16bits
#if (defined(__GNUC__) && defined(__i386__)) || defined(__WATCOMC__) \
  || defined(_MSC_VER) || defined (__BORLANDC__) || defined (__TURBOC__)
#define get16bits(d) (*((const uint16_t *) (d)))
#endif

#if !defined (get16bits)
#define get16bits(d) ((((uint32_t)(((const uint8_t *)(d))[1])) << 8)\
                       +(uint32_t)(((const uint8_t *)(d))[0]) )
#endif
// end code block for SuperFastHash

using namespace std;

/**
 * SuperFastHash function from Paul Hsieh (http://www.azillionmonkeys.com/qed/hash.html).
 * Wrapped in a struct and modified to accept a string (instead of a char* and a
 * length) by Kevin Gimpel.
 */
struct SuperFastHash {
	uint32_t operator()(const string ss) const {
		unsigned int len = ss.length();
		const char* data = ss.c_str();
		uint32_t hash = len, tmp;
		int rem;

		if (len <= 0 || data == NULL) return 0;

		rem = len & 3;
		len >>= 2;

		/* Main loop */
		for (;len > 0; len--) {
			hash  += get16bits (data);
			tmp    = (get16bits (data+2) << 11) ^ hash;
			hash   = (hash << 16) ^ tmp;
			data  += 2*sizeof (uint16_t);
			hash  += hash >> 11;
		}

		/* Handle end cases */
		switch (rem) {
			case 3: hash += get16bits (data);
					hash ^= hash << 16;
					hash ^= data[sizeof (uint16_t)] << 18;
					hash += hash >> 11;
					break;
			case 2: hash += get16bits (data);
					hash ^= hash << 11;
					hash += hash >> 17;
					break;
			case 1: hash += *data;
					hash ^= hash << 10;
					hash += hash >> 1;
		}

		/* Force "avalanching" of final 127 bits */
		hash ^= hash << 3;
		hash += hash >> 5;
		hash ^= hash << 4;
		hash += hash >> 17;
		hash ^= hash << 25;
		hash += hash >> 6;

		return hash;
	}
};

struct SuperFastHashWString {
	uint32_t operator()(const wstring ss) const {
		unsigned int len = ss.length();
		const wchar_t* data = ss.c_str();
		uint32_t hash = len, tmp;
		int rem;

		if (len <= 0 || data == NULL) return 0;

		rem = len & 3;
		len >>= 2;

		/* Main loop */
		for (;len > 0; len--) {
			hash  += get16bits (data);
			tmp    = (get16bits (data+2) << 11) ^ hash;
			hash   = (hash << 16) ^ tmp;
			data  += 2*sizeof (uint16_t);
			hash  += hash >> 11;
		}

		/* Handle end cases */
		switch (rem) {
			case 3: hash += get16bits (data);
					hash ^= hash << 16;
					hash ^= data[sizeof (uint16_t)] << 18;
					hash += hash >> 11;
					break;
			case 2: hash += get16bits (data);
					hash ^= hash << 11;
					hash += hash >> 17;
					break;
			case 1: hash += *data;
					hash ^= hash << 10;
					hash += hash >> 1;
		}

		/* Force "avalanching" of final 127 bits */
		hash ^= hash << 3;
		hash += hash >> 5;
		hash ^= hash << 4;
		hash += hash >> 17;
		hash ^= hash << 25;
		hash += hash >> 6;

		return hash;
	}
};

struct MurmurHash2 {
	unsigned int operator()(const string ss) const {
		int len = ss.length();
		const void* key = ss.c_str();
		//unsigned int seed = 10;	// TODO: allow this to be specified as a command-line parameter?

        // 'm' and 'r' are mixing constants generated offline.
        // They're not really 'magic', they just happen to work well.
        const unsigned int m = 0x5bd1e995;
        const int r = 24;

        // Initialize the hash to a 'random' value
        unsigned int h = 10 ^ len;

        // Mix 4 bytes at a time into the hash
        const unsigned char * data = (const unsigned char *)key;

        while(len >= 4)
        {
                unsigned int k = *(unsigned int *)data;

                k *= m;
                k ^= k >> r;
                k *= m;

                h *= m;
                h ^= k;

                data += 4;
                len -= 4;
        }

        // Handle the last few bytes of the input array
        switch(len)
        {
        case 3: h ^= data[2] << 16;
        case 2: h ^= data[1] << 8;
        case 1: h ^= data[0];
                h *= m;
        };

        // Do a few final mixes of the hash to ensure the last few
        // bytes are well-incorporated.
        h ^= h >> 13;
        h *= m;
        h ^= h >> 15;

        return h;
	}
};

struct MurmurHash2WString {
	unsigned int operator()(const wstring ss) const {
		int len = ss.length();
		const void* key = ss.c_str();
		//unsigned int seed = 10;	// TODO: allow this to be specified as a command-line parameter?

        // 'm' and 'r' are mixing constants generated offline.
        // They're not really 'magic', they just happen to work well.
        const unsigned int m = 0x5bd1e995;
        const int r = 24;

        // Initialize the hash to a 'random' value
        unsigned int h = 10 ^ len;

        // Mix 4 bytes at a time into the hash
        const unsigned wchar_t * data = (const unsigned wchar_t *)key;

        while(len >= 4)
        {
                unsigned int k = *(unsigned int *)data;

                k *= m;
                k ^= k >> r;
                k *= m;

                h *= m;
                h ^= k;

                data += 4;
                len -= 4;
        }

        // Handle the last few bytes of the input array
        switch(len)
        {
        case 3: h ^= data[2] << 16;
        case 2: h ^= data[1] << 8;
        case 1: h ^= data[0];
                h *= m;
        };

        // Do a few final mixes of the hash to ensure the last few
        // bytes are well-incorporated.
        h ^= h >> 13;
        h *= m;
        h ^= h >> 15;

        return h;
	}
};

//-----------------------------------------------------------------------------
// MurmurHash2, 64-bit versions, by Austin Appleby

//typedef unsigned long long uint64_t;

// 64-bit hash for 64-bit platforms
struct MurmurHash64A {
	uint64_t operator()(const string ss) const {
		int len = ss.length();
		const void* key = ss.c_str();
		//unsigned int seed = 10;	// TODO: allow this to be specified as a command-line parameter?
		const uint64_t m = 0xc6a4a7935bd1e995;
		const int r = 47;

		uint64_t h = 10 ^ (len * m);

		const uint64_t * data = (const uint64_t *)key;
		const uint64_t * end = data + (len/8);

		while(data != end)
		{
			uint64_t k = *data++;

			k *= m;
			k ^= k >> r;
			k *= m;
			h ^= k;
			h *= m;
		}
		const unsigned char * data2 = (const unsigned char*)data;
		switch(len & 7)
		{
		case 7: h ^= uint64_t(data2[6]) << 48;
		case 6: h ^= uint64_t(data2[5]) << 40;
		case 5: h ^= uint64_t(data2[4]) << 32;
		case 4: h ^= uint64_t(data2[3]) << 24;
		case 3: h ^= uint64_t(data2[2]) << 16;
		case 2: h ^= uint64_t(data2[1]) << 8;
		case 1: h ^= uint64_t(data2[0]);
	        h *= m;
		};
		h ^= h >> r;
		h *= m;
		h ^= h >> r;
		return h;
	}
};

struct MurmurHash2UnsignedInt {
	unsigned int operator()(const unsigned int ss) const {
		int len = sizeof(ss);
		const void* key = &ss;
		//unsigned int seed = 10;	// TODO: allow this to be specified as a command-line parameter?

        // 'm' and 'r' are mixing constants generated offline.
        // They're not really 'magic', they just happen to work well.
        const unsigned int m = 0x5bd1e995;
        const int r = 24;
        // Initialize the hash to a 'random' value
        unsigned int h = 10 ^ len;
        // Mix 4 bytes at a time into the hash
        const unsigned char * data = (const unsigned char *)key;

        while(len >= 4)
        {
                unsigned int k = *(unsigned int *)data;

                k *= m;
                k ^= k >> r;
                k *= m;

                h *= m;
                h ^= k;

                data += 4;
                len -= 4;
        }

        // Handle the last few bytes of the input array
        switch(len)
        {
        case 3: h ^= data[2] << 16;
        case 2: h ^= data[1] << 8;
        case 1: h ^= data[0];
                h *= m;
        };

        // Do a few final mixes of the hash to ensure the last few
        // bytes are well-incorporated.
        h ^= h >> 13;
        h *= m;
        h ^= h >> 15;
        return h;
	}
};

// The following hash function can be used for vectors of short ints.
// The hash function only looks at (at most) the first 7 items in the vector.
// It was originally developed for hashing word class n-grams in which
// each integer is a word class.
// The constants were chosen by hand using a greedy search based on the
// number of collisions that occurred when hashing all of the n-grams
// in one 5-gram and one 7-gram word class language model.
struct ProductHashVectorShortInt {
	unsigned int operator()(const vector<short int> v) const {
		int h = 1;
		int magic0 = 902;
		int magic[7];
		magic[0] = 7;
		magic[1] = 2523;
		magic[2] = 3759625;
		magic[3] = 109118;
		magic[4] = 1282949;
		magic[5] = 723891;
		magic[6] = 54420;

		int numDigits = v.size();
		if (numDigits > 7) numDigits = 7;
		for (int i = 0; i < numDigits; ++i) {
			if (v[i] < 0) {
				h -= v[i];
			} else if (v[i] == 0) {
				h += magic0;
			} else {
				h += (v[i] * magic[i]);
			}
		}
		if (h < 0) h = -h;
        return h;
	}
};

// The following hash function can be used for small vectors of ints.
// The hash function only looks at (at most) the first 4 items in the vector.
// It was originally developed for hashing lexical and word class patterns in which
// each integer corresponds to a word or word class.
struct ProductHashVectorInt {
	unsigned int operator()(const vector<int> v) const {
		int h = 1;
		int magic0 = 7;
		int magic[5];
		// Time: 320.07
		magic[0] = 15;
		magic[1] = 2523;
		magic[2] = 72381;
		magic[3] = 290857;
		magic[4] = 3759625;

		/* // Time: 321.25
		magic[0] = 15;
		magic[1] = 77;
		magic[2] = 119;
		magic[3] = 2907;
		magic[4] = 37515;
		*/

		int numDigits = v.size();
		if (numDigits > 5) numDigits = 5;
		for (int i = 0; i < numDigits; ++i) {
			if (v[i] < 0) {
				h -= v[i];
			} else if (v[i] == 0) {
				h += magic0;
			} else {
				h += (v[i] * magic[i]);
			}
		}
		if (h < 0) h = -h;
        return h;
	}
};

// The following hash function can be used for pairs of ints.
struct ProductHashPairInts {
	unsigned int operator()(const pair<int, int> p) const {
		int h = 1;
		int magic0 = 7;
		int magic1 = 123;
		int magic2 = 75891;

		if (p.first < 0) {
			h -= p.first;
		} else if (p.first == 0) {
			h += magic0;
		} else {
			h += (p.first * magic1);
		}

		if (p.second < 0) {
			h -= p.second;
		} else if (p.second == 0) {
			h += magic0;
		} else {
			h += (p.second * magic2);
		}

		if (h < 0) h = -h;
        return h;


/*        if (p.first < 0) {
			return p.second;
		}
		if (p.second < 0) {
			return p.first;
		}

        return (p.first * p.second);
        */
	}
};

// The following is an identity hash function for an unsigned int.
struct IdentityHashUnsignedInt {
	unsigned int operator()(const unsigned int p) const {
		return p;
	}
};

// string equality unary function for hash maps/sets.
struct eqstring {
	bool operator()(const string& s1, const string& s2) const {
		return (s1 == s2);
	}
};

// wstring equality unary function for hash maps/sets.
struct eqwstring {
	bool operator()(const wstring& s1, const wstring& s2) const {
		return (s1 == s2);
	}
};

// unsigned int equality unary function for hash maps/sets.
struct equnsignedint {
	bool operator()(const unsigned int& s1, const unsigned int& s2) const {
		return (s1 == s2);
	}
};

// vector<short int> equality unary function for hash maps/sets.
struct eqvectorshortint {
	bool operator()(const vector<short int>& s1, const vector<short int>& s2) const {
		return (s1 == s2);
	}
};

// vector<int> equality unary function for hash maps/sets.
struct eqvectorint {
	bool operator()(const vector<int>& s1, const vector<int>& s2) const {
		return (s1 == s2);
	}
};

// pair<int, int> equality unary function for hash maps/sets.
struct eqpairints {
	bool operator()(const pair<int, int>& s1, const pair<int, int>& s2) const {
		return (s1 == s2);
	}
};

#endif	/* HASHING_H_ */
