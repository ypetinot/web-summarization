class RegistrableObject: {

 public:
  
  /* register object */
  void register_object();

  /* unregister object */
  void unregister_object();

 protected:

  /* constructor */
  RegistrableObject( const ProbabilisticObject po );

  /* registration proceedure - implemented by sub-classes */
  virtual void _register() = 0;

  /* unregistration procedure - implemented by sub-classes */
  virtual void _unregister() = 0;

  /* registration status */
  bool _registered;

};
