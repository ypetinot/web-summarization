#ifndef __SERIALIZATION_GOOGLE_HASH_MAP_HPP__
#define __SERIALIZATION_GOOGLE_HASH_MAP_HPP__

// MS compatible compilers support #pragma once
#if defined(_MSC_VER) && (_MSC_VER >= 1020)
# pragma once
#endif

/////////1/////////2/////////3/////////4/////////5/////////6/////////7/////////8
// serialization for google hash_map templates

#include <boost/config.hpp>
#ifdef BOOST_HAS_HASH
#include BOOST_HASH_MAP_HEADER

#include <boost/serialization/utility.hpp>
#include <boost/serialization/hash_collections_save_imp.hpp>
#include <boost/serialization/hash_collections_load_imp.hpp>
#include <boost/serialization/split_free.hpp>

#include <google/sparse_hash_map>
#include <google/dense_hash_map>

namespace boost { 
namespace serialization {

namespace google {

template<class Archive, class Container>
struct archive_input_hash_map
{
    inline void operator()(
        Archive &ar, 
        Container &s, 
        const unsigned int v
    ){
        typedef BOOST_DEDUCED_TYPENAME Container::value_type type;
        detail::stack_construct<Archive, type> t(ar, v);
        // borland fails silently w/o full namespace
        ar >> boost::serialization::make_nvp("item", t.reference());
        std::pair<BOOST_DEDUCED_TYPENAME Container::const_iterator, bool> result = 
            s.insert(t.reference());
        // note: the following presumes that the map::value_type was NOT tracked
        // in the archive.  This is the usual case, but here there is no way
        // to determine that.  
        if(result.second){
            ar.reset_object_address(
                & (result.first->second),
                & t.reference().second
            );
        }
    }
};

} // google

template<
    class Archive, 
    class Key, 
    class HashFcn, 
    class EqualKey,
    class Allocator
>
inline void save(
		 Archive & ar,
		 const ::google::sparse_hash_map<
		 Key, HashFcn, EqualKey, Allocator
		 > &t,
		 const unsigned int file_version
		 ){
  boost::serialization::stl::save_hash_collection<
  Archive, 
    ::google::sparse_hash_map<
  Key, HashFcn, EqualKey, Allocator
    >
    >(ar, t);
}

template<
    class Archive, 
    class Key, 
    class HashFcn, 
    class EqualKey,
    class Allocator
>
inline void load(
    Archive & ar,
    ::google::sparse_hash_map<
        Key, HashFcn, EqualKey, Allocator
    > &t,
    const unsigned int file_version
){
    boost::serialization::stl::load_hash_collection<
        Archive,
	  ::google::sparse_hash_map<
            Key, HashFcn, EqualKey, Allocator
        >,
	  boost::serialization::google::archive_input_hash_map<
            Archive, 
	      ::google::sparse_hash_map<
                Key, HashFcn, EqualKey, Allocator
            >
        >
    >(ar, t);
}

// split non-intrusive serialization function member into separate
// non intrusive save/load member functions
template<
    class Archive, 
    class Key, 
    class HashFcn, 
    class EqualKey,
    class Allocator
>
inline void serialize(
    Archive & ar,
    ::google::sparse_hash_map<
        Key, HashFcn, EqualKey, Allocator
    > &t,
    const unsigned int file_version
){
    boost::serialization::split_free(ar, t, file_version);
}

} // namespace serialization
} // namespace boost

#endif // BOOST_HAS_HASH
#endif //
