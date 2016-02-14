#ifndef __HIERARCHY_DOCUMENT__
#define __HIERARCHY_DOCUMENT__

#include "serialization.h"

#include <string>

using namespace std;

class HierarchyDocument {

 public:

  /* default constructor - for deserialization purposes only */
  HierarchyDocument();

  /* constructor */
  HierarchyDocument(string url, string description);

  /* url getter */
  string get_url() const;

  /* description getter */
  string get_description() const;

 protected:

  /* url */
  string _url;

  /* description */
  string _description;

 private:

  friend class boost::serialization::access;
  template<class Archive>
    void serialize(Archive & ar, const unsigned int version)
    {
      ar & boost::serialization::make_nvp("_url", _url);
      ar & boost::serialization::make_nvp("_description", _description);
    }

};

#endif
