#ifndef __REGISTRABLE_OBJECT_H__
#define __REGISTRABLE_OBJECT_H__

// TODO : is this still needed since we are separating objects and the distributions that are placed on them ?

/* Abstracts the notion of an object that can be mapped to a unique id and that, based of this id, can be registered or unregistered from a Distribution instance */
// TODO : is there a better denomination for this concept ?
// TODO : if this implies Gibbs sampling (and to some extent it does, maybe I should move this class under an appropriate namespace)

// TODO : should registration be driven by this class or by the distribution with which each instance is registered ? => consider how the sampler will register/unregister instances of this class

class RegistrableObject {

 public:
  
  /* register object */
  void register_object();

  /* unregister object */
  void unregister_object();

 protected:

  /* constructor */
  // TODO: remove
  //RegistrableObject( const ProbabilisticObject& po );
  RegistrableObject();

  /* registration procedure - implemented by sub-classes */
  virtual void _register() = 0;

  /* unregistration procedure - implemented by sub-classes */
  virtual void _unregister() = 0;

  /* registration status */
  bool _registered;

};

#endif
